import std/macros
import std/logging
import std/strformat
import sqnim
import vm

proc regGblFun*(v: HSQUIRRELVM, f: SQFUNCTION, fname: cstring) =
  sq_pushstring(v,fname,-1)
  sq_newclosure(v,f,0) # create a new function
  discard sq_newslot(v,-3,SQFalse)

macro sqBind*(vm, body): untyped =
  result = newStmtList()
  for bodyStmt in body:
    if bodyStmt.kind == nnkConstSection:
      # declare a constant section
      let constSection = bodyStmt
      for constDef in constSection:
        # declare a constant
        let constName = constDef[0]
        let constValue = constDef[2]
        result.add(newCall(ident("sq_pushconsttable"), vm))
        result.add(newCall(ident("sq_pushstring"), vm, newStrLitNode(constName.repr), newLit(-1)))
        result.add(newCall(ident("push"), vm, constValue))
        result.add(newNimNode(nnkDiscardStmt).add(newCall(ident("sq_newslot"), vm, newLit(-3), newLit(SQTrue))))
        result.add(newCall(ident("sq_pop"), vm, newLit(1)))

proc rootTbl*(v: HSQUIRRELVM): HSQOBJECT =
  sq_resetobject(result)
  sq_pushroottable(v)
  discard sq_getstackobj(v, -1, result)
  sq_pop(v, 1)

proc pushFunc*(v: HSQUIRRELVM, o: HSQOBJECT, name: string) =
  sq_pushobject(v, o)
  sq_pushstring(v, name.cstring, -1)
  discard sq_get(v, -2)

macro sqCall*(v, o, name, args): untyped =
  result = newStmtList()
  # push function
  result.add(newCall(ident("pushFunc"), v, o, name))
  
  # push args
  result.add(newCall(ident("push"), v, o))
  for arg in args:
    result.add(newCall(ident("push"), v, arg))
  
  # call func
  result.add(newNimNode(nnkDiscardStmt).add(newCall(ident("sq_call"), v, newLit(1 + args.len()), newLit(SQFalse), newLit(SQTrue))))
  result.add(newCall(ident("sq_pop"), v, newLit(1)))

macro sqCall*(o, name, args): untyped =
  let v = newDotExpr(ident("gVm"), ident("v"))
  result = newStmtList(newCall(ident("sqCall"), v, o, name, args))

macro sqCall*(name, args): untyped =
  let v = newDotExpr(ident("gVm"), ident("v"))
  result = newStmtList(newCall(ident("sqCall"), v, newCall("rootTbl", v), name, args))

proc getArr*(v: HSQUIRRELVM, o: HSQOBJECT, arr: var seq[string]) =
  sq_pushobject(v, o)
  sq_pushnull(v)
  while SQ_SUCCEEDED(sq_next(v, -2)):
    var str: cstring
    discard sq_getstring(v, -1, str)
    arr.add($str)
    sq_pop(v, 2)
  sq_pop(v, 1)

proc getarray*(v: HSQUIRRELVM, i: int, arr: var seq[string]): SQRESULT =
  var obj: HSQOBJECT
  result = sq_getstackobj(v, i, obj)
  getArr(v, obj, arr)

proc get(v: HSQUIRRELVM, i: int, value: var int): SQRESULT =
  sq_getinteger(v, i, value)

proc get(v: HSQUIRRELVM, i: int, value: var int32): SQRESULT =
  var r: int
  result = sq_getinteger(v, i, r)
  value = r.int32

proc get(v: HSQUIRRELVM, i: int, value: var bool): SQRESULT =
  var tmp = 0
  result = sq_getinteger(v, i, tmp)
  value = tmp != 0

proc get(v: HSQUIRRELVM, i: int, value: var float): SQRESULT =
  var val: SQFloat
  result = sq_getfloat(v, i, val)
  value = val.float

proc get(v: HSQUIRRELVM, i: int, value: var string): SQRESULT =
  var val: SQString
  result = sq_getstring(v, i, val)
  value = $val

proc get(v: HSQUIRRELVM, i: int, value: var HSQOBJECT): SQRESULT =
  sq_getstackobj(v, i, value)

template get*[T](v: HSQUIRRELVM, index: int, value: var T): SQRESULT =
  get(v, index, value)

template getf*[T](v: HSQUIRRELVM, o: HSQOBJECT, name: string, value: var T) =
  sq_pushobject(v, o)
  sq_pushstring(v, name.cstring, -1)
  if SQ_FAILED(sq_get(v, -2)):
    sq_pop(v, 1)
  else:
    discard get(v, -1, value)
    sq_pop(v, 2)

template getf*[T](name: string, value: var T) =
  getf(gVm.v, rootTbl(gVm.v), name, value)

template getf*[T](o: HSQOBJECT, name: string, value: var T) =
  getf(gVm.v, o, name, value)

template call*(v: HSQUIRRELVM, o: HSQOBJECT, name: string; args: openArray[untyped]) =
  pushFunc(v, o, name)

  sq_pushobject(v, o)
  for arg in args:
    push(v, arg)
  discard sq_call(v, 1 + args.len, SQFalse, SQTrue)
  sq_pop(v, 1)

proc call*(v: HSQUIRRELVM, o: HSQOBJECT, name: string) =
  pushFunc(v, o, name)

  sq_pushobject(v, o)
  discard sq_call(v, 1, SQFalse, SQTrue)
  sq_pop(v, 1)

template callFunc*[T](v: HSQUIRRELVM, res: var T, o: HSQOBJECT, name: string; args: openArray[untyped] = @[]) =
  let top = sq_gettop(v)
  pushFunc(v, o, name)

  sq_pushobject(v, o)
  for arg in args:
    push(v, arg)
  discard sq_call(v, 1 + args.len, SQTrue, SQTrue)
  discard get(v, -1, res)
  sq_settop(v, top)

template callFunc*[T](o: HSQOBJECT, res: var T, name: string; args: openArray[untyped]) =
  gVm.v.callFunc(res, o, name, args)

proc call*(o: HSQOBJECT, name: string) =
  call(gVm.v, o, name)

template call*(name: string; args: openArray[untyped]) =
  call(gVm.v, rootTbl(gVm.v), name, args)

proc call*(name: string) =
  call(gVm.v, rootTbl(gVm.v), name)

proc paramCount*(v: HSQUIRRELVM, obj: HSQOBJECT, name: string): int =
  let top = sq_gettop(v)
  push(v, obj)
  sq_pushstring(v, name, -1)
  if SQ_FAILED(sq_get(v, -2)):
    sq_settop(v, top)
    debug fmt"can't find {name} function"
    return 0

  var nparams, nfreevars: int
  discard sq_getclosureinfo(v, -1, nparams, nfreevars)
  debug fmt"{name} function found with {nparams} parameters"
  sq_settop(v, top)
  nparams

proc rawexists*(obj: HSQOBJECT, name: string): bool =
  var v = gVm.v
  let top = sq_gettop(v)
  push(v, obj)
  sq_pushstring(v, name, -1)
  if SQ_SUCCEEDED(sq_rawget(v, -2)):
    let oType = sq_gettype(v, -1)
    sq_settop(v, top)
    return oType != OT_NULL
  sq_settop(v, top)
  return false

proc getId*(o: HSQOBJECT): int =
  result = 0
  if o.rawexists("_id"):
    getf(gVm.v, o, "_id", result)

template setf*[T](o: HSQOBJECT, key: string, obj: T) =
  let top = sq_gettop(gVm.v)
  sq_pushobject(gVm.v, o)
  sq_pushstring(gVm.v, key.cstring, -1)
  push(gVm.v, obj)
  discard sq_rawset(gVm.v, -3)
  sq_settop(gVm.v, top)

proc setId*(o: HSQOBJECT, id: int) {.inline.} =
  setf(o, "_id", id)

iterator items*(obj: HSQOBJECT): HSQOBJECT =
  sq_pushobject(gVm.v, obj)
  sq_pushnull(gVm.v)
  while SQ_SUCCEEDED(sq_next(gVm.v, -2)):
    var obj: HSQOBJECT
    discard get(gVm.v, -1, obj)
    yield obj
    sq_pop(gVm.v, 2)
  sq_pop(gVm.v, 2)

iterator pairs*(obj: HSQOBJECT): (string, HSQOBJECT) =
  sq_pushobject(gVm.v, obj)
  sq_pushnull(gVm.v)
  while SQ_SUCCEEDED(sq_next(gVm.v, -2)):
    var key: string
    var obj: HSQOBJECT
    discard get(gVm.v, -1, obj)
    discard get(gVm.v, -2, key)
    yield (key, obj)
    sq_pop(gVm.v, 2)
  sq_pop(gVm.v, 2)

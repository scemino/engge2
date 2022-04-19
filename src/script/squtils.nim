import std/macros
import std/logging
import std/strformat
import sqnim
import vm

proc regGblFun*(v: HSQUIRRELVM, f: SQFUNCTION, fname: cstring) =
  sq_pushroottable(v)
  sq_pushstring(v,fname,-1)
  sq_newclosure(v,f,0) # create a new function
  discard sq_newslot(v,-3,SQFalse)
  sq_pop(v,1) # pops the root table

macro sqBind*(vm, body): untyped =
  var funcs: seq[string]
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
    else:
      # declare a procedure
      let procDef = bodyStmt
      var name = procDef[0]
      let orgName = name
      var i = 1
      while name.repr in funcs:
        name = ident(orgName.repr & $i)
        i += 1
      funcs.add(name.repr)
      procDef.name = name
      var stmts = newStmtList()
      procDef.expectMinLen(4)
      var params: seq[NimNode]
      for iParam in 1..procDef[3].len-1:
        # tranform each param in squirrel param
        let paramNode = procDef[3][iParam]
        let identNode = paramNode[0]
        let typeNode = paramNode[1]

        case typeNode.repr:
        of "int", "SQInteger":
          params.add(identNode)
          stmts.add(newNimNode(nnkVarSection).add(newIdentDefs(identNode, typeNode)))
          stmts.add(newNimNode(nnkDiscardStmt).add(newCall(ident("sq_getinteger"), ident("v"), newLit(iParam+1), identNode)))
        of "float", "SQFloat":
          params.add(identNode)
          stmts.add(newNimNode(nnkVarSection).add(newIdentDefs(identNode, typeNode)))
          stmts.add(newNimNode(nnkDiscardStmt).add(newCall(ident("sq_getfloat"), ident("v"), newLit(iParam+1), identNode)))
        of "string", "SQString":
          params.add(identNode)
          stmts.add(newNimNode(nnkVarSection).add(newIdentDefs(identNode, typeNode)))
          stmts.add(newNimNode(nnkDiscardStmt).add(newCall(ident("sq_getstring"), ident("v"), newLit(iParam+1), identNode)))
        of "bool", "SQBool":
          params.add(identNode)
          stmts.add(newNimNode(nnkVarSection).add(newIdentDefs(identNode, typeNode)))
          stmts.add(newNimNode(nnkDiscardStmt).add(newCall(ident("sq_getbool"), ident("v"), newLit(iParam+1), identNode)))
        of "HSQOBJECT":
          params.add(identNode)
          stmts.add(newNimNode(nnkVarSection).add(newIdentDefs(identNode, typeNode)))
          stmts.add(newNimNode(nnkDiscardStmt).add(newCall(ident("sq_getstackobj"), ident("v"), newLit(iParam+1), identNode)))
        of "GGNode":
          let ggObj = ident("gg" & identNode.repr)
          params.add(ggObj)
          stmts.add(newNimNode(nnkVarSection).add(newIdentDefs(identNode, ident("HSQOBJECT"))))
          stmts.add(newNimNode(nnkDiscardStmt).add(newCall(ident("sq_getstackobj"), ident("v"), newLit(iParam+1), identNode)))
          stmts.add(newNimNode(nnkVarSection).add(newIdentDefs(ggObj, ident("GGNode"))))
          stmts.add(newAssignment(ggObj, newCall(ident("toGGObject"), ident("v"), identNode)))
        else:
          assert false, "unexpected param type: " & typeNode.repr
      # result
      let resultType = procDef[3][0]
      case resultType.repr:
        of "int", "SQInteger":
          stmts.add(newCall(ident("sq_pushinteger"), ident("v"), newCall(name, params)))
        of "float", "SQFloat":
          stmts.add(newCall(ident("sq_pushfloat"), ident("v"), newCall(name, params)))
        of "string", "SQString":
          stmts.add(newCall(ident("sq_pushstring"), ident("v"), newCall(name, params), newLit(-1)))
        of "HSQOBJECT":
          stmts.add(newCall(ident("sq_pushobject"), ident("v"), newCall(name, params)))
        of "GGNode":
          let ggResult = ident("ggResult")
          stmts.add(newNimNode(nnkVarSection).add(newIdentDefs(ggResult, ident("HSQOBJECT"))))
          stmts.add(newCall(ident("toHSQObject"), ident("v"), newCall(name, params), ggResult))
          stmts.add(newCall(ident("sq_pushobject"), ident("v"), ggResult))
        of "":
          stmts.add(newCall(name, params))
        else:
          assert false, "unexpected result type: " & resultType.repr
      # returns 1 to indicate that this function returns a value
      stmts.add(newLit(1))
      
      # create procedures
      let sqbdName = ident("sqbd_" & name.repr)
      # register function
      let regStmt = newCall(ident("regGblFun"), vm, sqbdName, newLit(orgName.repr))
      # add procedure definition
      result.add(procDef)
      # add squirrel procedure definition
      result.add(newProc(sqbdName, 
        [ident("SQInteger"), newIdentDefs(ident("v"), ident("HSQUIRRELVM"))],
        stmts, pragmas = newNimNode(nnkPragma).add(ident("cdecl"))))
      result.add(regStmt)

proc rootTbl*(v: HSQUIRRELVM): HSQOBJECT =
  sq_resetobject(result)
  sq_pushroottable(v)
  discard sq_getstackobj(v, -1, result)
  sq_pop(v, 1)

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
  sq_pushstring(v, name, -1)
  if SQ_FAILED(sq_get(v, -2)):
    sq_pop(v, 1)
  else:
    discard get(v, -1, value)
    sq_pop(v, 1)

template getf*[T](o: HSQOBJECT, name: string, value: var T) =
  getf(gVm.v, o, name, value)

proc call*(v: HSQUIRRELVM, o: HSQOBJECT, name: string; args: openArray[HSQOBJECT] = []) =
  sq_pushobject(v, o)
  sq_pushstring(v, name, -1)
  discard sq_get(v, -2)

  sq_pushobject(v, o)
  for arg in args:
    sq_pushobject(v, arg)
  discard sq_call(v, 1 + args.len, SQFalse, SQTrue)
  sq_pop(v, 1)

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

proc rawsafeget*(v: HSQUIRRELVM): SQInteger =
  let value = if SQ_SUCCEEDED(sq_rawget(v, -2)): 1 else: 0
  sq_pushinteger(v, value)
  1

proc rawexists*(obj: HSQOBJECT, name: string): bool =
  var v = gVm.v
  let top = sq_gettop(v)
  push(v, obj)
  sq_pushstring(v, name, -1)
  if SQ_SUCCEEDED(sq_rawget(v, -2)):
    let oType = sq_gettype(v, -1)
    sq_settop(v, top);
    return oType != OT_NULL
  sq_settop(v, top)
  return false

proc getId*(o: HSQOBJECT): int =
  result = 0
  if rawsafeget(gVm.v) == 1:
    getf(gVm.v, o, "_id", result)

proc setId*(o: HSQOBJECT, id: int) =
  sq_pushobject(gVm.v, o)
  sq_pushstring(gVm.v, "_id", -1)
  sq_pushinteger(gVm.v, id)
  discard sq_newslot(gVm.v, -3, false)

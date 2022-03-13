import std/[logging, random, sharedlist]
import glm
import sqnim
import thread
import vm
import engine
import functions

proc objectAt(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var obj: HSQOBJECT
  discard sq_getstackobj(v, 2, obj)
  var x, y: int
  if SQ_FAILED(sq_getinteger(v, 3, x)):
    return sq_throwerror(v, "objectAt invalid type " & $sq_gettype(v, 3))
  if SQ_FAILED(sq_getinteger(v, 4, y)):
    return sq_throwerror(v, "objectAt invalid type " & $sq_gettype(v, 4))
  for o in gEngine.objects.mitems:
    if o.obj == obj:
      o.pos = vec2f(x.float32, y.float32)
  0

proc createObject(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let numArgs = sq_gettop(v)
  if numArgs == 3:
    var sheet: cstring
    discard sq_getstring(v, 2, sheet)
    var anims: seq[string]
    sq_push(v, 3)
    sq_pushnull(v)
    while SQ_SUCCEEDED(sq_next(v, -2)):
      var name: cstring
      discard sq_getstring(v, -1, name)
      anims.add($name)
      sq_pop(v, 2)
    sq_pop(v, 1)
    let obj = gEngine.createObject(v, $sheet, anims)
    push(v, obj)
    return 1
  else:
    return sq_throwerror(v, "createObject called with invalid type")

proc sysRandom(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  if sq_gettype(v, 2) == OT_INTEGER:
    var min, max: int
    discard sq_getinteger(v, 2, min)
    discard sq_getinteger(v, 3, max)
    let value = gEngine.rand.rand(min..max)
    sq_pushinteger(v, value)
    return 1
  else:
    var min, max: SQFloat
    discard sq_getfloat(v, 2, min)
    discard sq_getfloat(v, 3, max)
    let value = gEngine.rand.rand(min..max)
    sq_pushfloat(v, value)
    return 1

proc startglobalthread(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let size = sq_gettop(v)
  var env_obj: HSQOBJECT
  sq_resetobject(env_obj)
  if SQ_FAILED(sq_getstackobj(v, 1, env_obj)):
    return sq_throwerror(v, "Couldn't get environment from stack")

  # create thread and store it on the stack
  discard sq_newthread(v, 1024)
  var thread_obj: HSQOBJECT
  sq_resetobject(thread_obj)
  if SQ_FAILED(sq_getstackobj(v, -1, thread_obj)):
    return sq_throwerror(v, "Couldn't get coroutine thread from stack")

  var args: seq[HSQOBJECT]
  for i in 0..<size-2:
    var arg: HSQOBJECT
    sq_resetobject(arg)
    if SQ_FAILED(sq_getstackobj(v, 3 + i, arg)):
      return sq_throwerror(v, "Couldn't get coroutine args from stack")
    args.add(arg)

  # get the closure
  var closureObj: HSQOBJECT
  sq_resetobject(closureObj)
  if SQ_FAILED(sq_getstackobj(v, 2, closureObj)):
    return sq_throwerror(v, "Couldn't get coroutine thread from stack")

  var name: cstring
  if SQ_SUCCEEDED(sq_getclosurename(v, 2)):
    discard sq_getstring(v, -1, name)

  let threadName = if not name.isNil: name else: "anonymous"
  var thread = newThread($threadName, true, v, thread_obj, env_obj, closureObj, args)
  sq_pop(v, 1)
  info("start thread (" & $threadName & ")")
  if not name.isNil:
    sq_pop(v, 1) # pop name
  sq_pop(v, 1) # pop closure
  gThreads.add(thread)

  # call the closure in the thread
  if not thread.call():
    return sq_throwerror(v, "call failed")

  sq_pushinteger(v, thread.id)
  return 1

proc breakfunc(v: HSQUIRRELVM, funcFactory: proc (v: HSQUIRRELVM): Function): SQInteger =
  for t in gThreads:
    if t.getThread() == v:
      t.suspend()
      gEngine.funcs.add(funcFactory(v))
      return -666
  sq_throwerror(v, "failed to get thread")

proc breakhere(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var numFrames: SQInteger
  if SQ_FAILED(sq_getinteger(v, 2, numFrames)):
    return sq_throwerror(v, "failed to get numFrames")
  breakfunc(v, proc (v: HSQUIRRELVM): Function = newBreakHereFunction(v, numFrames))

proc breaktime(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var time: SQFloat
  if SQ_FAILED(sq_getfloat(v, 2, time)):
    return sq_throwerror(v, "failed to get time")
  breakfunc(v, proc (v: HSQUIRRELVM): Function = newBreakTimeFunction(v, time))

proc register_gamelib*(v: HSQUIRRELVM) =
  v.regGblFun(createObject, "createObject")
  v.regGblFun(sysRandom, "random")
  v.regGblFun(objectAt, "objectAt")
  v.regGblFun(startglobalthread, "startglobalthread")
  v.regGblFun(breakhere, "breakhere")
  v.regGblFun(breaktime, "breaktime")
  
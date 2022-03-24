import std/logging
import sqnim
import thread
import vm
import squtils
import callback
import engine

proc activeController(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  error("TODO: activeController: not implemented")
  # harcode mouse
  sq_pushinteger(v, 1)
  1

proc addCallback(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let count = sq_gettop(v)
  var duration: SQFloat
  if SQ_FAILED(sq_getfloat(v, 2, duration)):
    return sq_throwerror(v, "failed to get duration")
  var meth: HSQOBJECT;
  sq_resetobject(meth);
  if SQ_FAILED(sq_getstackobj(v, 3, meth)) or not sq_isclosure(meth):
    return sq_throwerror(v, "failed to get method")

  var methodName: string
  if SQ_SUCCEEDED(sq_getclosurename(v, 3)):
    var tmpMethodName: SQString
    discard sq_getstring(v, -1, tmpMethodName)
    methodName = $tmpMethodName

  var args: seq[HSQOBJECT]
  for i in 4..count:
    var arg: HSQOBJECT
    sq_resetobject(arg)
    if SQ_FAILED(sq_getstackobj(v, i, arg)):
      return sq_throwerror(v, "failed to get argument " & $i)
    args.add(arg)

  let callback = newCallback(duration, methodName, args)
  gEngine.callbacks.add(callback)

  sq_pushinteger(v, callback.id)
  return 1

proc breakfunc(v: HSQUIRRELVM, setConditionFactory: proc (t: Thread)): SQInteger =
  for t in gThreads:
    if t.getThread() == v:
      t.suspend()
      setConditionFactory(t)
      return -666
  sq_throwerror(v, "failed to get thread")

proc breakhere(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var numFrames: SQInteger
  if SQ_FAILED(sq_getinteger(v, 2, numFrames)):
    return sq_throwerror(v, "failed to get numFrames")
  breakfunc(v, proc (t: Thread) = t.numFrames = numFrames)

proc breaktime(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var time: SQFloat
  if SQ_FAILED(sq_getfloat(v, 2, time)):
    return sq_throwerror(v, "failed to get time")
  breakfunc(v, proc (t: Thread) = t.waitTime = time)

proc sqChr(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var value: int
  get(v, 2, value)
  var s: string
  s.add(chr(value))
  push(v, s)
  1

proc pstartthread(v: HSQUIRRELVM, global: bool): SQInteger {.cdecl.} =
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
  var thread = newThread($threadName, global, v, thread_obj, env_obj, closureObj, args)
  sq_pop(v, 1)
  info("create thread (" & $threadName & ")")
  if not name.isNil:
    sq_pop(v, 1) # pop name
  sq_pop(v, 1) # pop closure
  gThreads.add(thread)

  sq_pushinteger(v, thread.id)
  return 1

proc startthread(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  pstartthread(v, false)

proc stopthread(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var id: int
  if SQ_FAILED(sq_getinteger(v, 2, id)):
    sq_pushinteger(v, 0)
    return 1

  for t in gThreads:
    if t.id == id:
      t.stop()
      sq_pushinteger(v, 0)
      return 1

  sq_pushinteger(v, 0)
  1

proc startglobalthread(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  pstartthread(v, true)

proc register_syslib*(v: HSQUIRRELVM) =
  v.regGblFun(activeController, "activeController")
  v.regGblFun(addCallback, "addCallback")
  v.regGblFun(breakhere, "breakhere")
  v.regGblFun(breaktime, "breaktime")
  v.regGblFun(sqChr, "chr")
  v.regGblFun(startglobalthread, "startglobalthread")
  v.regGblFun(startthread, "startthread")
  v.regGblFun(stopthread, "stopthread")
  
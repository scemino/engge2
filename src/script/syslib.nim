import std/[logging, strformat]
import sqnim
import vm
import squtils
import ../audio/audio
import ../game/thread
import ../game/callback
import ../game/engine
import ../game/room
import ../game/breakwhilecond
import ../game/utils

proc activeController(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  error("TODO: activeController: not implemented")
  # harcode mouse
  sq_pushinteger(v, 1)
  1

proc addCallback(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets a timer of duration seconds. 
  ## 
  ## When the timer is up, method will be executed. 
  ## Use this method so that the callback will get saved. 
  ## That is, if you set a callback to call method in 30 minutes, play the game for 10 minutes, save and quit; 
  ## when you return to the game, it will remember that it needs to wait 20 minutes before calling method. 
  ## If the game is paused, all callback timers are paused. 
  ## Note, method cannot be code, it must be a defined script or function (otherwise, the game wouldn't be able to save what it needs to do when the timer is up).
  ## .. code-block:: Squirrel
  ## if (actorTalking()) {
  ##   addCallback(30, doADance)    // Wait another 30 seconds
  ##   return
  ##}
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

proc addFolder(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Registers a folder that assets can appear in. 
  ## 
  ## Only used for development builds where the assets are not bundled up. 
  ## Use in the Boot.nut process. 
  ## Not necessary for release. 
  0

proc breakfunc(v: HSQUIRRELVM, setConditionFactory: proc (t: Thread)): SQInteger =
  let t = thread(v)
  if t.isNil:
    sq_throwerror(v, "failed to get thread")
  else:
    t.suspend()
    setConditionFactory(t)
    return -666

proc breakhere(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## When called in a function started with startthread, execution is suspended for count frames. 
  ## It is an error to call breakhere in a function that was not started with startthread.
  ## Particularly useful instead of breaktime if you just want to wait 1 frame, since not all machines run at the same speed.
  ## . code-block:: Squirrel
  ## while(isSoundPlaying(soundPhoneBusy)) {
  ##   breakhere(5)
  ##}
  var numFrames: SQInteger
  if SQ_FAILED(sq_getinteger(v, 2, numFrames)):
    return sq_throwerror(v, "failed to get numFrames")
  breakfunc(v, proc (t: Thread) = t.numFrames = numFrames)

proc breaktime(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## When called in a function started with startthread, execution is suspended for time seconds.
  ## It is an error to call breaktime in a function that was not started with startthread.
  ## 
  ## . code-block:: Squirrel
  ## for (local x = 1; x < 4; x += 1) {
  ##   playSound(soundPhoneRinging)
  ##   breaktime(5.0)
  ## }
  var time: SQFloat
  if SQ_FAILED(sq_getfloat(v, 2, time)):
    return sq_throwerror(v, "failed to get time")
  breakfunc(v, proc (t: Thread) = t.waitTime = time)

proc breakwhilecond(v: HSQUIRRELVM, name: string, pred: Predicate): SQInteger =
  var curThread = thread(v)
  if curThread.isNil:
    return sq_throwerror(v, "Current thread should be created with startthread")
  
  info "curThread.id: " & $curThread.id
  info fmt"add breakwhilecond pid={curThread.id}"
  gEngine.tasks.add newBreakWhileCond(curThread.id, name, pred)
  return -666

proc breakwhilerunning(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Breaks while the thread referenced by threadId is running.
  ## Once the thread finishes execution, the method will continue running.
  ## It is an error to call breakwhilerunning in a function that was not started with startthread. 
  ## 
  ## . code-block:: Squirrel
  ## local waitTID = 0
  ## 
  ##    if ( g.in_flashback && HotelElevator.requestedFloor == 13 ) {
  ##     waitTID = startthread(HotelElevator.avoidPenthouse)
  ##     breakwhilerunning(waitTID)
  ## }
  ## waitTID = 0
  ## if (HotelElevator.requestedFloor >= 0) {
  ##     // Continue executing other code
  ## }
  var id = 0
  if sq_gettype(v, 2) == OT_INTEGER:
    discard sq_getinteger(v, 2, id)
  info "breakwhilerunning: " & $id
  
  var t = thread(id);
  if t.isNil:
    warn "thread not found: " & $id
    return 0

  breakwhilecond(v, fmt"breakwhilerunning({id})", proc (): bool = thread(id).isNil)

proc breakwhileanimating(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## When called in a function started with startthread, execution is suspended until animatingItem has completed its animation.
  ## Note, animatingItem can be an actor or an object.
  ## It is an error to call breakwhileanimating in a function that was not started with `startthread`.
  ## 
  ## . code-block:: Squirrel
  ## actorFace(ray, FACE_LEFT)
  ## actorCostume(ray, "RayVomit")
  ## actorPlayAnimation(ray, "vomit")
  ## breakwhileanimating(ray)
  ## actorCostume(ray, "RayAnimation")
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  breakwhilecond(v, fmt"breakwhileanimating({obj.name})", proc (): bool = not thread(id).isNil)

proc breakwhilewalking(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## If an actor is specified, breaks until actor has finished walking.
  ## Once arrived at destination, the method will continue running.
  ## It is an error to call breakwhilewalking in a function that was not started with `startthread`.
  ## 
  ## . code-block:: Squirrel
  ## startthread(@(){
  ##    actorWalkTo(currentActor, Nickel.copyTron)
  ##    breakwhilewalking(currentActor)
  ##    pushSentence(VERB_USE, nickel, Nickel.copyTron)
  ##})
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  breakwhilecond(v, fmt"breakwhilewalking({obj.name})", proc (): bool = not obj.walkTo.isNil and obj.walkTo.enabled)

proc breakwhilesound(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Breaks until specified sound has finished playing.
  ## Once sound finishes, the method will continue running.
  var sound = sound(v, 2)
  if not sound.isNil:
    result = breakwhilecond(v, fmt"breakwhilesound({sound.id})", proc (): bool = gEngine.audio.playing(sound))
  else:
    var soundDef = soundDef(v, 2)
    result = breakwhilecond(v, fmt"breakwhilesound({soundDef.id})", proc (): bool = gEngine.audio.playing(soundDef))

proc gameTime(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns how long (in seconds) the game has been played for in total (not just this session).
  #
  ## Saved when the game is saved.
  ## Also used for testing.
  ## The value is a float, so 1 = 1 second, 0.5 = half a second.
  ## 
  ## . code-block:: Squirrel
  ## if (gameTime() > (time+testerTronTimeOut)) { // Do something
  ## }
  sq_pushfloat(v, gEngine.time * 1000.0)
  1

proc inputController(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  error("TODO: inputController: not implemented")
  0

proc logEvent(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let numArgs = sq_gettop(v)
  var msg: string
  var event: SQString
  if SQ_SUCCEEDED(sq_getstring(v, 2, event)):
    msg = $event
  if numArgs == 3:
    if SQ_SUCCEEDED(sq_getstring(v, 3, event)):
      msg = msg & $event
  info("event: " & msg)
  0

proc microTime(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  # Returns game time in milliseconds. 
  # Based on when the machine is booted and runs all the time (not paused or saved).
  # See also gameTime, which is in seconds. 
  sq_pushfloat(v, gEngine.time * 1000.0)
  1

proc removeCallback(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  # removeCallback(id: int) remove the given callback
  var id = 0
  if SQ_FAILED(sq_getinteger(v, 2, id)):
    return sq_throwerror(v, "failed to get callback")
  for i in 0..<gEngine.callbacks.len:
    let cb = gEngine.callbacks[i]
    if cb.id == id:
      gEngine.callbacks.del i
      return 0
  0

proc pstartthread(v: HSQUIRRELVM, global: bool): SQInteger {.cdecl.} =
  let size = sq_gettop(v)

  var env_obj: HSQOBJECT
  sq_resetobject(env_obj)
  if SQ_FAILED(sq_getstackobj(v, 1, env_obj)):
    return sq_throwerror(v, "Couldn't get environment from stack")

  # create thread and store it on the stack
  discard sq_newthread(gVm.v, 1024)
  var thread_obj: HSQOBJECT
  sq_resetobject(thread_obj)
  if SQ_FAILED(sq_getstackobj(gVm.v, -1, thread_obj)):
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
  var thread = newThread($threadName, global, gVm.v, thread_obj, env_obj, closureObj, args)
  sq_pop(gVm.v, 1)
  info("create thread (" & $threadName & ")" & " id: " & $thread.id & " v=" & $(cast[int](thread.v.unsafeAddr)))
  if not name.isNil:
    sq_pop(v, 1) # pop name
  sq_pop(v, 1) # pop closure
  
  gEngine.threads.add(thread)

  # call the closure in the thread
  if not thread.call():
    return sq_throwerror(v, "call failed")

  sq_pushinteger(v, thread.id)
  return 1

proc startthread(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Calls a function to be run in a new thread.
  ## 
  ## The function is called and executes until the first breakhere, breaktime (or other break command), or the function returns.
  ## The function cannot return a value.
  ## The value returned from startthread is a threadid that can be used to check the state of, or kill the thread.
  ##
  ## Threads started with startthread are local to the room.
  ## When the room exits, all threads are stopped unless the thread is started with startglobalthread.
  ## 
  ## . code-block:: Squirrel
  ## startthread(watchExit)
  ## local photocopier_id = startthread(usePhotocopier, 10)
  ## 
  ## See also:
  ## * `startglobalthread`
  ## * `stopthread`
  pstartthread(v, false)

proc stopthread(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Stops a thread specified by threadid.
  ## 
  ## If the thread is not running, the command does nothing.
  ## 
  ## See also:
  ## * `startthread`
  ## * `startglobalthread`
  var id: int
  if SQ_FAILED(sq_getinteger(v, 2, id)):
    sq_pushinteger(v, 0)
    return 1

  let t = thread(id)
  if not t.isNil:
    t.stop()

  sq_pushinteger(v, 0)
  1

proc startglobalthread(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ##  Calls a function to be run in a new thread.
  ## 
  ## The value returned from `startglobalthread` is a threadid that can be used to check the state of, or kill the thread.
  ## Unlike `startthread` which starts a local thread that will be stopped when the room is exited, scripts started with startglobalthread will keep running, even after switching rooms.
  ## 
  ## See also: 
  ## * `startthread`
  ## * `stopthread`
  pstartthread(v, true)

proc threadid(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns the thread ID of the currently running script/thread.
  ## 
  ## If no thread is running, it will return 0.
  ## 
  ## . code-block:: Squirrel
  ## Phone <-
  ## {
  ##     phoneRingingTID = 0
  ##     script phoneRinging(number) {
  ##         phoneRingingTID = threadid()
  ##         ...
  ##     }
  ##     function clickedButton(...) {
  ##         if (!phoneRingingTID) {
  ##             ...
  ##         }
  ##     }
  ## }
  let t = thread(v)
  if not t.isNil:
    sq_pushinteger(v, t.id)
  else:
    sq_pushinteger(v, 0)
  1

proc register_syslib*(v: HSQUIRRELVM) =
  ## Registers the game system library.
  ## 
  ## It adds all the system functions in the given Squirrel virtual machine `v`.
  v.regGblFun(activeController, "activeController")
  v.regGblFun(addCallback, "addCallback")
  v.regGblFun(addFolder, "addFolder")
  v.regGblFun(breakhere, "breakhere")
  v.regGblFun(breaktime, "breaktime")
  v.regGblFun(breakwhileanimating, "breakwhileanimating")
  v.regGblFun(breakwhilerunning, "breakwhilerunning")
  v.regGblFun(breakwhilesound, "breakwhilesound")
  v.regGblFun(breakwhilewalking, "breakwhilewalking")
  v.regGblFun(gameTime, "gameTime")
  v.regGblFun(inputController, "inputController")
  v.regGblFun(logEvent, "logEvent")
  v.regGblFun(microTime, "microTime")
  v.regGblFun(removeCallback, "removeCallback")
  v.regGblFun(startglobalthread, "startglobalthread")
  v.regGblFun(startthread, "startthread")
  v.regGblFun(stopthread, "stopthread")
  v.regGblFun(threadid, "threadid")
  
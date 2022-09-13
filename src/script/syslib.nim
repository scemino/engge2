import std/[logging, strformat, strutils]
import sqnim
import vm
import glm
import squtils
import ../audio/audio
import ../game/thread
import ../game/callback
import ../game/cutscene
import ../game/engine
import ../game/ids
import ../game/room
import ../game/inputstate
import ../game/tasks/breakwhilecond
import ../game/motors/motor
import ../scenegraph/dialog
import ../gfx/color
import ../util/utils
import ../sys/app

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
  var duration: float
  if SQ_FAILED(get(v, 2, duration)):
    return sq_throwerror(v, "failed to get duration")
  var meth: HSQOBJECT
  sq_resetobject(meth)
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
      return sq_throwerror(v, fmt"failed to get argument {i}".cstring)
    args.add(arg)

  let callback = newCallback(newCallbackId(), duration, methodName, args)
  gEngine.callbacks.add(callback)

  push(v, callback.id)
  return 1

proc addFolder(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Registers a folder that assets can appear in. 
  ## 
  ## Only used for development builds where the assets are not bundled up. 
  ## Use in the Boot.nut process. 
  ## Not necessary for release. 
  0

proc breakfunc(v: HSQUIRRELVM, setConditionFactory: proc (t: ThreadBase)): SQInteger =
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
  let t = sq_gettype(v, 2)
  if t == OT_INTEGER:
    var numFrames: int
    if SQ_FAILED(get(v, 2, numFrames)):
      return sq_throwerror(v, "failed to get numFrames")
    return breakfunc(v, proc (t: ThreadBase) = t.numFrames = numFrames)
  elif t == OT_FLOAT:
    var time: float
    if SQ_FAILED(get(v, 2, time)):
      return sq_throwerror(v, "failed to get time")
    return breakfunc(v, proc (t: ThreadBase) = t.waitTime = time)
  else:
    return sq_throwerror(v, fmt"failed to get numFrames (wrong type = {t})")

proc breaktime(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## When called in a function started with startthread, execution is suspended for time seconds.
  ## It is an error to call breaktime in a function that was not started with startthread.
  ## 
  ## . code-block:: Squirrel
  ## for (local x = 1; x < 4; x += 1) {
  ##   playSound(soundPhoneRinging)
  ##   breaktime(5.0)
  ## }
  var time: float
  if SQ_FAILED(get(v, 2, time)):
    return sq_throwerror(v, "failed to get time")
  if time == 0f:
    breakfunc(v, proc (t: ThreadBase) = t.numFrames = 1)  
  else:
    breakfunc(v, proc (t: ThreadBase) = t.waitTime = time)

proc breakwhilecond(v: HSQUIRRELVM, name: string, pred: Predicate): SQInteger =
  let curThread = thread(v)
  if curThread.isNil:
    return sq_throwerror(v, "Current thread should be created with startthread")
  
  info "curThread.id: " & $curThread.getId()
  info fmt"add breakwhilecond name={name} pid={curThread.getId()}"
  gEngine.tasks.add newBreakWhileCond(curThread.getId(), name, pred)
  return -666

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
  let obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  breakwhilecond(v, fmt"breakwhileanimating({obj.key})", proc (): bool = not obj.nodeAnim.disabled)

proc breakwhilecamera(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Breaks while a camera is moving.
  ## Once the thread finishes execution, the method will continue running.
  ## It is an error to call breakwhilecamera in a function that was not started with startthread. 
  breakwhilecond(v, "breakwhilecamera()", proc (): bool = not gEngine.cameraPanTo.isNil and gEngine.cameraPanTo.enabled)

proc breakwhilecutscene(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Breaks while a cutscene is running.
  ## Once the thread finishes execution, the method will continue running.
  ## It is an error to call breakwhilecutscene in a function that was not started with startthread. 
  breakwhilecond(v, "breakwhilecutscene()", proc (): bool = not gEngine.cutscene.isNil)

proc breakwhiledialog(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Breaks while a dialog is running.
  ## Once the thread finishes execution, the method will continue running.
  ## It is an error to call breakwhiledialog in a function that was not started with startthread. 
  breakwhilecond(v, "breakwhiledialog()", proc (): bool = gEngine.dlg.state != DialogState.None)

proc breakwhileinputoff(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Breaks while input is not active.
  ## Once the thread finishes execution, the method will continue running.
  ## It is an error to call breakwhileinputoff in a function that was not started with startthread. 
  breakwhilecond(v, "breakwhileinputoff()", proc (): bool = not gEngine.inputState.inputActive)

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
    discard get(v, 2, id)
  info "breakwhilerunning: " & $id
  
  let t = thread(id)
  if t.isNil:
    let sound = sound(id)
    if sound.isNil:
      warn "thread and sound not found: " & $id
      return 0
    else:
      result = breakwhilecond(v, fmt"breakwhilerunning({id})", proc (): bool = not sound(id).isNil)
  else:
    result = breakwhilecond(v, fmt"breakwhilerunning({id})", proc (): bool = not thread(id).isNil)

proc isSomeoneTalking(): bool =
  ## Returns true if at least 1 actor is talking.
  for obj in gEngine.actors:
    if not obj.talking.isNil and obj.talking.enabled:
      return true
  for layer in gEngine.room.layers:
    for obj in layer.objects:
      if not obj.talking.isNil and obj.talking.enabled:
        return true

proc breakwhiletalking(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## If an actor is specified, breaks until actor has finished talking.
  ## If no actor is specified, breaks until ALL actors have finished talking.
  ## Once talking finishes, the method will continue running.
  ## It is an error to call breakwhiletalking in a function that was not started with startthread. 
  ## 
  ## . code-block:: Squirrel
  ## while(closeToWillie()) {
  ##     local line = randomfrom(lines)
  ##     breakwhiletalking(willie)
  ##     mumbleLine(willie, line)
  ##     breakwhiletalking(willie)
  ## }
  let nArgs = sq_gettop(v)
  if nArgs == 1:
    breakwhilecond(v, fmt"breakwhiletalking(all)", isSomeoneTalking)
  elif nArgs == 2:
    let obj = obj(v, 2)
    if obj.isNil:
      return sq_throwerror(v, "failed to get object")
    breakwhilecond(v, fmt"breakwhiletalking({obj.name})", proc (): bool = not obj.talking.isNil and obj.talking.enabled)
  else:
    sq_throwerror(v, "Invalid number of arguments for breakwhiletalking")

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
  let obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  breakwhilecond(v, fmt"breakwhilewalking({obj.name})", proc (): bool = not obj.walkTo.isNil and obj.walkTo.enabled)

proc breakwhilesound(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Breaks until specified sound has finished playing.
  ## Once sound finishes, the method will continue running.
  let sound = sound(v, 2)
  if not sound.isNil:
    result = breakwhilecond(v, fmt"breakwhilesound({sound.id})", proc (): bool = gEngine.audio.playing(sound))
  else:
    let soundDef = soundDef(v, 2)
    if not soundDef.isNil:
      result = breakwhilecond(v, fmt"breakwhilesound({soundDef.id})", proc (): bool = gEngine.audio.playing(soundDef))

proc cutscene(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let nArgs = sq_gettop(v)

  var envObj: HSQOBJECT
  sq_resetobject(envObj)
  if SQ_FAILED(sq_getstackobj(v, 1, envObj)):
    return sq_throwerror(v, "Couldn't get environment from stack")

  # create thread and store it on the stack
  discard sq_newthread(gVm.v, 1024)
  var threadObj: HSQOBJECT
  sq_resetobject(threadObj)
  if SQ_FAILED(sq_getstackobj(gVm.v, -1, threadObj)):
    return sq_throwerror(v, "failed to get coroutine thread from stack")

  # get the closure
  var closure: HSQOBJECT
  sq_resetobject(closure)
  if SQ_FAILED(sq_getstackobj(v, 2, closure)):
    return sq_throwerror(v, "failed to get cutscene closure")

  # get the cutscene override closure
  var closureOverride: HSQOBJECT
  sq_resetobject(closureOverride)
  if nArgs == 3:
    if SQ_FAILED(sq_getstackobj(v, 3, closureOverride)):
      return sq_throwerror(v, "failed to get cutscene override closure")

  let cutscene = newCutscene(v, threadObj, closure, closureOverride, envObj)
  gEngine.cutscene = cutscene

  # call the closure in the thread
  discard cutscene.update(0f)
  breakwhilecutscene(v)

proc cutsceneOverride(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  info "cutsceneOverride"
  cast[Cutscene](gEngine.cutscene).cutsceneOverride()
  0

proc `$`(obj: var HSQOBJECT): string =
  case obj.objType:
  of OT_INTEGER:
    result = $sq_objtointeger(obj)
  of OT_FLOAT:
    result = $sq_objtofloat(obj)
  of OT_STRING:
    result = $sq_objtostring(obj)
  of OT_ARRAY:
    var strings: seq[string]
    for item in obj.mitems:
      strings.add $item[]
    result = join(strings, ", ")
    result = fmt"[{result}]"
  of OT_TABLE:
    var strings: seq[string]
    for (k, item) in obj.mpairs:
      strings.add "{" & k & ": " & $item[] & "}"
    result = "{" & join(strings, ", ") & "}"
  of OT_CLOSURE:
    result = "closure"
  of OT_NATIVECLOSURE:
    result = "native closure"
  of OT_THREAD:
    result = "thread"
  of OT_NULL:
    result = "null"
  else:
    result = $obj.objType

proc dumpvar(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var obj: HSQOBJECT
  discard get(v, 2, obj)
  info $obj
  0

proc exCommand(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  warn "exCommand not implemented"
  0

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

proc sysInclude(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var filename: string
  if SQ_FAILED(get(v, 2, filename)):
    return sq_throwerror(v, "failed to get filename")
  execNutEntry(v, filename)

proc inputController(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  error "TODO: inputController: not implemented"

proc inputHUD(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var on: bool
  if SQ_FAILED(get(v, 2, on)):
    return sq_throwerror(v, "failed to get on")
  gEngine.inputState.inputHUD = on

proc inputOff(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  if gEngine.cutscene.isNil:
    gEngine.inputState.inputActive = false
    gEngine.inputState.showCursor = false

proc inputOn(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  if gEngine.cutscene.isNil:
    gEngine.inputState.inputActive = true
    gEngine.inputState.showCursor = true

proc inputSilentOff(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  gEngine.inputState.inputActive = false

proc sysInputState(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let numArgs = sq_gettop(v)
  if numArgs == 1:
    let state = cast[int](gEngine.inputState.getState())
    push(v, state)
    return 1
  elif numArgs == 2:
    var state: int
    if SQ_FAILED(get(v, 2, state)):
      return sq_throwerror(v, "failed to get state")
    gEngine.inputState.setState(cast[InputStateFlag](state))
    return 0
  return sq_throwerror(v, "TODO: inputState: not implemented")

proc inputVerbs(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var on: bool
  if SQ_FAILED(get(v, 2, on)):
    return sq_throwerror(v, "failed to get isActive")
  info fmt"inputVerbs: {on}"
  gEngine.inputState.inputVerbsActive = on
  1

proc isInputOn(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let isActive = gEngine.inputState.inputActive
  push(v, isActive)
  1

proc logEvent(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let numArgs = sq_gettop(v)
  var msg, event: string
  if SQ_FAILED(get(v, 2, event)):
    return sq_throwerror(v, "failed to get event")
  if numArgs == 3:
    if SQ_FAILED(get(v, 3, event)):
      return sq_throwerror(v, "failed to get message")
    msg = event & ": " & msg
  info(msg)
  0

proc logInfo(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Like a print statement, but gets sent to the output log file instead.
  ## Useful for testing. 
  var msg: string
  if SQ_FAILED(get(v, 2, msg)):
    return sq_throwerror(v, "failed to get message")
  info(msg)
  0

proc logWarning(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sends a warning message to the output log file.
  var msg: string
  if SQ_FAILED(get(v, 2, msg)):
    return sq_throwerror(v, "failed to get message")
  warn(msg)
  0

proc microTime(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  # Returns game time in milliseconds. 
  # Based on when the machine is booted and runs all the time (not paused or saved).
  # See also gameTime, which is in seconds. 
  push(v, gEngine.time * 1000.0)
  1

proc moveCursorTo(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var x, y: int32
  if SQ_FAILED(get(v, 2, x)):
    return sq_throwerror(v, "Failed to get x")
  if SQ_FAILED(get(v, 3, y)):
    return sq_throwerror(v, "Failed to get y")
  var t: float
  if SQ_FAILED(get(v, 4, t)):
    return sq_throwerror(v, "Failed to get time")

  mouseMove(vec2(x, y))
  # TODO: use time
  1

proc removeCallback(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  # removeCallback(id: int) remove the given callback
  var id = 0
  if SQ_FAILED(get(v, 2, id)):
    return sq_throwerror(v, "failed to get callback")
  for i in 0..<gEngine.callbacks.len:
    let cb = gEngine.callbacks[i]
    if cb.id == id:
      gEngine.callbacks.del i
      return 0
  0

proc setAmbientLight(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var c = 0
  if SQ_FAILED(get(v, 2, c)):
    return sq_throwerror(v, "failed to get color")
  gEngine.room.ambientLight = rgb(c)

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

  var threadName = if name.isNil: "anonymous" else: $name
  threadName = fmt"{threadName} {$closure_srcname(closureObj)} ({closure_line(closureObj)})"
  let thread = newThread($threadName, global, gVm.v, thread_obj, env_obj, closureObj, args)
  sq_pop(gVm.v, 1)
  info("create thread (" & $threadName & ")" & " id: " & $thread.getId() & " v=" & $(cast[int](thread.v.unsafeAddr)))
  if not name.isNil:
    sq_pop(v, 1) # pop name
  sq_pop(v, 1) # pop closure
  
  gEngine.threads.add(thread)

  # call the closure in the thread
  if not thread.call():
    return sq_throwerror(v, "call failed")

  sq_pushinteger(v, thread.getId())
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
  if SQ_FAILED(get(v, 2, id)):
    push(v, 0)
    return 1

  let t = thread(id)
  if not t.isNil:
    t.stop()

  push(v, 0)
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
    push(v, t.getId())
  else:
    push(v, 0)
  1

proc threadpauseable(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Specify whether a thread should be pauseable or not.
  ## If a thread is not pauseable, it won't be possible to pause this thread.
  let t = thread(v, 2)
  if t.isNil:
    return sq_throwerror(v, "failed to get thread")
  var pauseable = 0
  if SQ_FAILED(get(v, 3, pauseable)):
    return sq_throwerror(v, "failed to get pauseable")
  t.pauseable = pauseable != 0

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
  v.regGblFun(breakwhilecamera, "breakwhilecamera")
  v.regGblFun(breakwhilecutscene, "breakwhilecutscene")
  v.regGblFun(breakwhiledialog, "breakwhiledialog")
  v.regGblFun(breakwhileinputoff, "breakwhileinputoff")
  v.regGblFun(breakwhilerunning, "breakwhilerunning")
  v.regGblFun(breakwhilesound, "breakwhilesound")
  v.regGblFun(breakwhiletalking, "breakwhiletalking")
  v.regGblFun(breakwhilewalking, "breakwhilewalking")
  v.regGblFun(cutscene, "cutscene")
  v.regGblFun(cutsceneOverride, "cutsceneOverride")
  v.regGblFun(dumpvar, "dumpvar")
  v.regGblFun(exCommand, "exCommand")
  v.regGblFun(gameTime, "gameTime")
  v.regGblFun(sysInclude, "include")
  v.regGblFun(inputController, "inputController")
  v.regGblFun(inputHUD, "inputHUD")
  v.regGblFun(inputOff, "inputOff")
  v.regGblFun(inputOn, "inputOn")
  v.regGblFun(inputSilentOff, "inputSilentOff")
  v.regGblFun(sysInputState, "inputState")
  v.regGblFun(inputVerbs, "inputVerbs")
  v.regGblFun(isInputOn, "isInputOn")
  v.regGblFun(logEvent, "logEvent")
  v.regGblFun(logInfo, "logInfo")
  v.regGblFun(logWarning, "logWarning")
  v.regGblFun(microTime, "microTime")
  v.regGblFun(moveCursorTo, "moveCursorTo")
  v.regGblFun(removeCallback, "removeCallback")
  v.regGblFun(setAmbientLight, "setAmbientLight")
  v.regGblFun(startglobalthread, "startglobalthread")
  v.regGblFun(startthread, "startthread")
  v.regGblFun(stopthread, "stopthread")
  v.regGblFun(threadid, "threadid")
  v.regGblFun(threadpauseable, "threadpauseable")
  
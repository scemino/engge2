import std/logging
import std/strformat
import sqnim
import ../script/vm
import ../script/squtils
import ids
import thread
import inputstate
import engine
import room

type 
  CutsceneState = enum
    csStart
    csCheckEnd
    csOverride
    csCheckOverride
    csEnd
    csQuit
  Cutscene* = ref object of ThreadBase
    id: int
    v: HSQUIRRELVM
    threadObj, closure, closureOverride, envObj: HSQOBJECT
    state: CutsceneState
    stopped: bool
    showCursor: bool
    inputState: InputStateFlag
    actor: Object

proc newCutscene*(v: HSQUIRRELVM, threadObj, closure, closureOverride, envObj: HSQOBJECT): Cutscene =
  result = Cutscene(name: "cutscene", v: v, threadObj: threadObj, closure: closure, closureOverride: closureOverride, envObj: envObj, id: newThreadId(), inputState: gEngine.inputState.getState(), actor: gEngine.followActor, showCursor: gEngine.inputState.showCursor, state: csStart)
  info fmt"Create cutscene {result.id} with input: 0x{result.inputState.int:X}"
  gEngine.inputState.inputActive = false
  gEngine.inputState.inputVerbsActive = false
  gEngine.inputState.showCursor = false
  sq_addref(gVm.v, result.threadObj)
  sq_addref(gVm.v, result.closure)
  sq_addref(gVm.v, result.closureOverride)
  sq_addref(gVm.v, result.envObj)

proc destroy*(self: Cutscene) =
  discard sq_release(gVm.v, self.threadObj)
  discard sq_release(gVm.v, self.closure)
  discard sq_release(gVm.v, self.closureOverride)
  discard sq_release(gVm.v, self.envObj)

method getId*(self: Cutscene): int =
  self.id

method getName*(self: Cutscene): string =
  "Cutscene"

method getThread*(self: Cutscene): HSQUIRRELVM =
  cast[HSQUIRRELVM](self.threadObj.value.pThread)

proc start(self: Cutscene) =
  self.state = csCheckEnd
  let thread = self.getThread()
  # call the closure in the thread
  let top = sq_gettop(thread)
  sq_pushobject(thread, self.closure)
  sq_pushobject(thread, self.envObj)
  if SQ_FAILED(sq_call(thread, 1, SQFalse, SQTrue)):
    sq_settop(thread, top)
    error "Couldn't call cutscene"

proc isStopped(self: Cutscene): bool =
  if self.stopped:
    return true;
  sq_getvmstate(self.getThread()) == 0

proc checkEndCutscene(self: Cutscene) =
  if self.isStopped():
    self.state = csEnd
    debug fmt"end cutscene: {self.getId()}"

proc cutsceneOverride*(self: Cutscene) =
  self.state = csOverride

proc hasOverride*(self: Cutscene): bool =
  not sq_isnull(self.closureOverride)

proc doCutsceneOverride(self: Cutscene) =
  if self.hasOverride:
    self.state = csCheckOverride
    debug "start cutsceneOverride"
    sq_pushobject(self.getThread(), self.closureOverride)
    sq_pushobject(self.getThread(), self.envObj)
    if SQ_FAILED(sq_call(self.getThread(), 1, SQFalse, SQTrue)):
      error "Couldn't call cutsceneOverride"
    return
  self.state = csEnd;

proc checkEndCutsceneOverride(self: Cutscene) =
  if self.isStopped():
    self.state = csEnd
    debug "end checkEndCutsceneOverride"

method stop*(self: Cutscene) =
  self.state = csQuit
  debug "End cutscene"
  gEngine.inputState.setState(self.inputState)
  gEngine.inputState.showCursor = self.showCursor
  info fmt"Restore cutscene input: {self.inputState}"
  gEngine.follow(gEngine.actor)
  call("onCutsceneEnded")
  discard sq_wakeupvm(self.v, SQFalse, SQFalse, SQTrue, SQFalse)
  discard sq_suspendvm(self.getThread())

method update*(self: Cutscene, elapsed: float): bool =
  if self.waitTime > 0:
    self.waitTime -= elapsed
    if self.waitTime <= 0:
      self.waitTime = 0
      self.resume()
  elif self.numFrames > 0:
    self.numFrames -= 1
    self.numFrames = 0
    self.resume()

  case self.state:
  of csStart:
    debug "startCutscene"
    self.start()
    return false
  of csCheckEnd:
    self.checkEndCutscene()
    return false
  of csOverride:
    debug "doCutsceneOverride"
    self.doCutsceneOverride()
    return false
  of csCheckOverride:
    debug "checkEndCutsceneOverride"
    self.checkEndCutsceneOverride()
    return false
  of csEnd:
    debug "endCutscene"
    self.stop()
    return false
  of csQuit:
    return true
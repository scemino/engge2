import std/logging
import std/strformat
import sqnim
import ../script/vm
import ../script/squtils
import ../game/ids
import ../game/thread

type 
  CutsceneState = enum
    csStart
    csCheckEnd
    csOverride
    csCheckOverride
    csEnd
    csQuit
  Cutscene = ref object of ThreadBase
    id: int
    v: HSQUIRRELVM
    threadObj, closure, closureOverride, envObj: HSQOBJECT
    state: CutsceneState
    stopped: bool

proc newCutscene*(v: HSQUIRRELVM, threadObj, closure, closureOverride, envObj: HSQOBJECT): Cutscene =
  result = Cutscene(v: v, threadObj: threadObj, closure: closure, closureOverride: closureOverride, envObj: envObj, id: newThreadId())
  info fmt"Create cutscene {result.id}"
  sq_addref(gVm.v, result.threadObj)
  sq_addref(gVm.v, result.closure)
  sq_addref(gVm.v, result.closureOverride)
  sq_addref(gVm.v, result.envObj)
  result.state = csStart

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
  cast[HSQUIRRELVM](self.thread_obj.value.pThread)

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

proc doCutsceneOverride(self: Cutscene) =
  if not sq_isnull(self.closureOverride):
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
  # m_engine.setInputState(m_inputState)
  # m_engine.follow(m_engine.getCurrentActor())
  call("onCutsceneEnded")
  discard sq_wakeupvm(self.v, SQFalse, SQFalse, SQTrue, SQFalse)
  discard sq_suspendvm(self.getThread())

method update*(self: Cutscene, elapsed: float): bool =
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
import std/logging
import std/strformat
import sqnim
import ids

type
  ThreadBaseObj* = object of RootObj
    name*: string
    global*: bool
    numFrames*: int
    waitTime*: float
    pauseable*: bool
    stopRequest: bool
    paused: bool
  ThreadBase* = ref ThreadBaseObj
  ThreadObj* = object of ThreadBase
    id: int
    v*: HSQUIRRELVM
    threadObj*, envObj*, closureObj*: HSQOBJECT
    args*: seq[HSQOBJECT]
    init: bool
  Thread* = ref ThreadObj

method getThread*(self: ThreadBase): HSQUIRRELVM {.base.} =
  discard

method getId*(self: ThreadBase): int {.base.} =
  discard

method getName*(self: ThreadBase): string {.base.} =
  discard

proc isSuspended*(self: ThreadBase): bool =
  let state = sq_getvmstate(self.getThread())
  return state != 1

proc isDead*(self: ThreadBase): bool =
  let state = sq_getvmstate(self.getThread())
  self.stopRequest or state == 0

proc resume*(self: ThreadBase) =
  if not self.isDead and self.isSuspended:
    # let state = sq_getvmstate(self.getThread())
    # info fmt"resume thread {self.getId()}, state={state}"
    discard sq_wakeupvm(self.getThread(), SQFalse, SQFalse, SQTrue, SQFalse)

proc suspend*(self: ThreadBase) =
  if self.pauseable and not self.isSuspended:
    discard sq_suspendvm(self.getThread())

proc pause*(self: ThreadBase) =
  if self.pauseable:
    self.paused = true
    self.suspend()

proc unpause*(self: ThreadBase) =
  self.paused = false
  self.resume()

method stop*(self: ThreadBase) {.base.} =
  discard

method update*(self: ThreadBase, elapsed: float): bool {.base.} =
  return false

proc `=destroy`*(self: var ThreadObj) =
  debug fmt"destroy thread {self.id}"
  for arg in self.args.mitems:
    discard sq_release(self.v, arg)  
  discard sq_release(self.v, self.threadObj)
  discard sq_release(self.v, self.envObj)
  discard sq_release(self.v, self.closureObj)

proc newThread*(name: string, global: bool, v: HSQUIRRELVM, threadObj, envObj, closureObj: HSQOBJECT, args: seq[HSQOBJECT]): Thread =
  result = Thread()
  result.id = newThreadId()
  result.name = name
  result.global = global
  result.v = v
  result.threadObj = threadObj
  result.envObj = envObj
  result.closureObj = closureObj
  result.args = args
  result.pauseable = true

  for arg in result.args.mitems:
    sq_addref(result.v, arg)  
  sq_addref(result.v, result.threadObj)
  sq_addref(result.v, result.envObj)
  sq_addref(result.v, result.closureObj)

method getThread*(self: Thread): HSQUIRRELVM =
  cast[HSQUIRRELVM](self.threadObj.value.pThread)

method getId*(self: Thread): int =
  self.id

method getName*(self: Thread): string =
  self.name

proc call*(self: Thread): bool =
  let thread = self.getThread()
  # call the closure in the thread
  let top = sq_gettop(thread)
  sq_pushobject(thread, self.closureObj)
  sq_pushobject(thread, self.envObj)
  for arg in self.args:
    sq_pushobject(thread, arg)
  if SQ_FAILED(sq_call(thread, 1 + self.args.len(), SQFalse, SQTrue)):
    sq_settop(thread, top)
    return false
  return true

method stop*(self: Thread) =
  self.stopRequest = true
  self.suspend()

method update*(self: Thread, elapsed: float): bool =
  if self.paused:
    discard
  elif self.waitTime > 0:
    self.waitTime -= elapsed
    if self.waitTime <= 0:
      self.waitTime = 0
      self.resume()
  elif self.numFrames > 0:
    self.numFrames -= 1
    self.numFrames = 0
    self.resume()
  self.isDead()

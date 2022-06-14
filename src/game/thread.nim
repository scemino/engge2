import std/logging
import std/strformat
import sqnim
import ids

type
  ThreadBase* = ref object of RootObj
    global*: bool
    numFrames*: int
    waitTime*: float
    pauseable*: bool
    stopRequest: bool
  Thread* = ref object of ThreadBase
    id: int
    name: string
    v*: HSQUIRRELVM
    threadObj*, envObj*, closureObj*: HSQOBJECT
    args*: seq[HSQOBJECT]
    init: bool

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
  if not self.isDead:
    # let state = sq_getvmstate(self.getThread())
    # info fmt"resume thread {self.getId()}, state={state}"
    if self.isSuspended:
      discard sq_wakeupvm(self.getThread(), SQFalse, SQFalse, SQTrue, SQFalse)

proc suspend*(self: ThreadBase) =
  if self.pauseable and not self.isSuspended:
    discard sq_suspendvm(self.getThread())

method stop*(self: ThreadBase) {.base.} =
  discard

method update*(self: ThreadBase, elapsed: float): bool {.base.} =
  return false

proc newThread*(name: string, global: bool, v: HSQUIRRELVM, threadObj, envObj, closureObj: HSQOBJECT, args: seq[HSQOBJECT]): Thread =
  new(result)
  result.id = newThreadId()
  result.name = name
  result.global = global
  result.v = v
  result.threadObj = threadObj
  result.envObj = envObj
  result.closureObj = closureObj
  result.args = args
  result.pauseable = true

  sq_addref(result.v, result.threadObj)
  sq_addref(result.v, result.envObj)
  sq_addref(result.v, result.closureObj)

method getThread*(self: Thread): HSQUIRRELVM =
  cast[HSQUIRRELVM](self.threadObj.value.pThread)

method getId*(self: Thread): int =
  self.id

method getName*(self: Thread): string =
  self.name

proc destroy*(self: Thread) =
  debug fmt"destroy thread {self.id}"
  discard sq_release(self.v, self.threadObj)
  discard sq_release(self.v, self.envObj)
  discard sq_release(self.v, self.closureObj)

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
  if self.waitTime > 0:
    self.waitTime -= elapsed
    if self.waitTime <= 0:
      self.waitTime = 0
      self.resume()
  elif self.numFrames > 0:
    self.numFrames -= 1
    self.numFrames = 0
    self.resume()
  self.isDead()

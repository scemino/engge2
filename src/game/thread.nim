import std/logging
import std/strformat
import sqnim
import ids

type
  Thread* = ref object of RootObj
    id*: int
    name*: string
    global*: bool
    v*: HSQUIRRELVM
    thread_obj*, env_obj*, closureObj*: HSQOBJECT
    args*: seq[HSQOBJECT]
    waitTime*: float
    numFrames*: int
    init: bool
    stopRequest: bool

proc newThread*(name: string, global: bool, v: HSQUIRRELVM, thread_obj, env_obj, closureObj: HSQOBJECT, args: seq[HSQOBJECT]): Thread =
  new(result)
  result.id = newThreadId()
  result.name = name
  result.global = global
  result.v = v
  result.thread_obj = thread_obj
  result.env_obj = env_obj
  result.closureObj = closureObj
  result.args = args

  sq_addref(result.v, result.thread_obj)
  sq_addref(result.v, result.envObj)
  sq_addref(result.v, result.closureObj)

proc getThread*(self: Thread): HSQUIRRELVM =
  cast[HSQUIRRELVM](self.thread_obj.value.pThread)

proc isSuspended*(self: Thread): bool =
  let state = sq_getvmstate(self.getThread())
  return state != 1

proc isDead*(self: Thread): bool =
  let state = sq_getvmstate(self.getThread())
  self.stopRequest or state == 0

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

proc resume*(self: Thread) =
  if not self.isDead:
    #let state = sq_getvmstate(self.getThread())
    #info fmt"resume thread {self.id}, state={state}"
    if self.isSuspended:
      discard sq_wakeupvm(self.getThread(), SQFalse, SQFalse, SQTrue, SQFalse)

proc suspend*(self: Thread) =
  if not self.isSuspended:
    discard sq_suspendvm(self.getThread())

proc stop*(self: Thread) =
  self.stopRequest = true
  self.suspend()

proc update*(self: Thread, elapsed: float): bool =
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

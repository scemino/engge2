import sqnim
import thread

type Function* = ref object of RootObj
  v: HSQUIRRELVM

method isElapsed(self: Function, elapsed: float): bool {.base.} =
  raise newException(CatchableError, "Method without implementation override")

proc update*(self: Function, elapsed: float): bool =
  if self.isElapsed(elapsed):
    for t in gThreads:
      if t.getThread() == self.v:
        t.resume()
        return true

type BreakHereFunction* = ref object of Function
  frameCounter, numFrames: int

proc newBreakHereFunction*(v: HSQUIRRELVM, numFrames: int): BreakHereFunction =
  new(result)
  result.v = v
  result.numFrames = numFrames

method isElapsed(self: BreakHereFunction, elapsed: float): bool =
  result = self.frameCounter >= self.numFrames
  if not result:
    self.frameCounter += 1

type BreakTimeFunction* = ref object of Function
  elapsed: float
  time: float

proc newBreakTimeFunction*(v: HSQUIRRELVM, time: float): BreakTimeFunction =
  new(result)
  result.v = v
  result.time = time

method isElapsed(self: BreakTimeFunction, elapsed: float): bool =
  self.elapsed += elapsed
  result = self.elapsed > self.time
  
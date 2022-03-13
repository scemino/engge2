import sqnim
import thread

type BreakTimeFunction* = ref object of RootObj
  v: HSQUIRRELVM
  elapsed: float
  done: bool
  time: float

proc newBreakTimeFunction*(v: HSQUIRRELVM, time: float): BreakTimeFunction =
  new(result)
  result.v = v
  result.time = time

proc update*(self: BreakTimeFunction, elapsed: float): bool =
  if not self.done:
    self.elapsed += elapsed
    let isElapsed = self.elapsed > self.time
    if isElapsed:
      self.done = true
      for t in gThreads:
        if t.getThread() == self.v:
          t.resume()
          return true
  self.done
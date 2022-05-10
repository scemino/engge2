import std/random as rnd
import motor
import ../room
import ../engine

type
  BlinkState = enum
    Closed
    Open
  Blink = ref object of Motor
    obj: Object
    state: BlinkState
    slice: HSlice[float, float]
    elapsed, duration: float

proc newBlink*(obj: Object, slice: HSlice[float, float]): Blink =
  new(result)
  result.obj = obj
  result.slice = slice
  result.state = Closed
  result.enabled = true
  result.duration = gEngine.rand.rand(slice)
  obj.showLayer("blink", false)

method update(self: Blink, el: float) =
  if self.state == Closed:
    # wait to blink
    self.elapsed += el
    if self.elapsed > self.duration:
      self.state = Open
      self.obj.showLayer("blink", true)
      self.elapsed = 0
  elif self.state == Open:
    # wait time the eyes are closed
    self.elapsed += el
    if self.elapsed > 0.25:
      self.obj.showLayer("blink", false)
      self.duration = gEngine.rand.rand(self.slice)
      self.elapsed = 0
      self.state = Closed
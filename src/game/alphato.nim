import motor
import room
import glm

type AlphaTo = ref object of Motor
    elapsed: float
    time: float
    obj: Object
    frm: float
    to: float
    speed: float

proc newAlphaTo*(time: float, obj: var Object, to: float): AlphaTo =
  new(result)
  result.time = time
  result.obj = obj
  result.frm = obj.color[3]
  result.to = to
  result.speed = to - result.frm
  result.enabled = true

method update(self: AlphaTo, el: float) =
  self.elapsed += el
  if self.elapsed > self.time:
    self.elapsed = self.time
    self.enabled = false
  let f = clamp(self.elapsed / self.time, 0, 1)
  self.obj.color[3] = self.frm + f * self.speed
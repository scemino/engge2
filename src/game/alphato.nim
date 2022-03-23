import motor
import room
import glm
import ../util/tween
import ../util/easing

type AlphaTo = ref object of Motor
    obj: Object
    tween: Tween[float]

proc newAlphaTo*(duration: float, obj: var Object, to: float): AlphaTo =
  new(result)
  result.obj = obj
  result.tween = newTween[float](obj.color[3], to, duration, linear)
  result.enabled = true

method update(self: AlphaTo, el: float) =
  self.tween.update(el)
  self.obj.color[3] = self.tween.current()
  self.enabled = self.tween.running()

import motor
import room
import ../util/tween
import ../util/easing

type RotateTo = ref object of Motor
    obj: Object
    tween: Tween[float]

proc newRotateTo*(duration: float, obj: var Object, to: float, im: InterpolationMethod): RotateTo =
  new(result)
  result.obj = obj
  result.tween = newTween[float](obj.rotation, to, duration, im)
  result.enabled = true

method update(self: RotateTo, el: float) =
  self.tween.update(el)
  self.obj.rotation = self.tween.current()
  self.enabled = self.tween.running()

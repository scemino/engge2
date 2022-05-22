import motor
import ../room
import ../../util/tween
import ../../util/easing
import ../../scenegraph/node

type AlphaTo = ref object of Motor
    obj: Object
    tween: Tween[float]

proc newAlphaTo*(duration: float, obj: Object, to: float, im: InterpolationMethod): AlphaTo =
  new(result)
  result.obj = obj
  result.tween = newTween[float](obj.node.alpha, to, duration, im)
  result.init()

method update(self: AlphaTo, el: float) =
  self.tween.update(el)
  self.obj.node.alpha = self.tween.current()
  if not self.tween.running():
    self.disable()

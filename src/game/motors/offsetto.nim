import glm
import motor
import ../room
import ../../util/tween
import ../../util/easing
import ../../scenegraph/node

type OffsetTo = ref object of Motor
    obj: Object
    tween: Tween[Vec2f]

proc newOffsetTo*(duration: float, obj: Object, pos: Vec2f, im: InterpolationMethod): OffsetTo =
  new(result)
  result.obj = obj
  result.tween = newTween[Vec2f](obj.node.offset, pos, duration, im)
  result.enabled = true

method update(self: OffsetTo, el: float) =
  self.tween.update(el)
  self.obj.node.offset = self.tween.current()
  self.enabled = self.tween.running()

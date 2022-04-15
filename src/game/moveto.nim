import motor
import room
import glm
import ../util/tween
import ../util/easing
import ../scenegraph/node

type MoveTo = ref object of Motor
    obj: Object
    tween: Tween[Vec2f]

proc newMoveTo*(duration: float, obj: Object, pos: Vec2f, im: InterpolationMethod): MoveTo =
  new(result)
  result.obj = obj
  result.tween = newTween[Vec2f](obj.node.pos, pos, duration, im)
  result.enabled = true

method update(self: MoveTo, el: float) =
  self.tween.update(el)
  self.obj.node.pos = self.tween.current()
  self.enabled = self.tween.running()

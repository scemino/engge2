import glm
import motor
import ../../scenegraph/node
import ../../util/tween
import ../../util/easing

type ScaleTo = ref object of Motor
    node: Node
    tween: Tween[float]

proc newScaleTo*(duration: float, node: Node, to: float, im: InterpolationMethod): ScaleTo =
  new(result)
  assert not node.isNil
  result.node = node
  result.tween = newTween[float](node.scale.x, to, duration, im)
  result.init()

method update(self: ScaleTo, el: float) =
  self.tween.update(el)
  self.node.scale = vec2(self.tween.current().float32, self.tween.current().float32)
  if not self.tween.running():
    self.disable()

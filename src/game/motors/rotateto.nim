import motor
import ../../scenegraph/node
import ../../util/tween
import ../../util/easing

type RotateTo = ref object of Motor
    node: Node
    tween: Tween[float]

proc newRotateTo*(duration: float, node: Node, to: float, im: InterpolationMethod): RotateTo =
  new(result)
  assert not node.isNil
  result.node = node
  result.tween = newTween[float](node.rotation, to, duration, im)
  result.init()

method update(self: RotateTo, el: float) =
  self.tween.update(el)
  self.node.rotation = self.tween.current()
  if not self.tween.running():
    self.disable()

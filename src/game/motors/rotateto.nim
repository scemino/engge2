import motor
import ../../scenegraph/node
import ../../util/tween
import ../../util/easing

type RotateTo = ref object of Motor
    node: Node
    rotation: float
    tween: Tween[float]

proc newRotateTo*(duration: float, node: Node, to: float, im: InterpolationMethod): RotateTo =
  new(result)
  assert not node.isNil
  result.node = node
  result.rotation = node.rotation
  result.tween = newTween[float](node.rotation, to, duration, im)
  result.init()

method disable*(self: RotateTo) =
  procCall self.Motor.disable()
  if self.tween.swing or self.tween.loop:
    self.node.rotation = self.rotation

method update(self: RotateTo, el: float) =
  self.tween.update(el)
  self.node.rotation = self.tween.current()
  if not self.tween.running():
    self.disable()

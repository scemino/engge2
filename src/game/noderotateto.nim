import task
import ../scenegraph/node
import ../util/tween
import ../util/easing

type NodeRotateTo = ref object of Task
    node: Node
    tween: Tween[float]

proc newNodeRotateTo*(duration: float, node: Node, to: float, im: InterpolationMethod): NodeRotateTo =
  new(result)
  result.node = node
  result.tween = newTween[float](node.rotation, to, duration, im)

method update(self: NodeRotateTo, el: float): bool =
  self.tween.update(el)
  self.node.rotation = self.tween.current()
  not self.tween.running()
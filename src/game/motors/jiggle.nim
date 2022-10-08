import glm
import motor
import ../../scenegraph/node

type Jiggle = ref object of Motor
  node: Node
  amount: float32
  jiggleTime: float32

proc newJiggle*(node: Node, amount: float): Jiggle =
  result = Jiggle(amount: amount.float32, node: node)
  result.init()

method update(self: Jiggle, elapsed: float) =
  self.jiggleTime += 20f * elapsed
  self.node.rotationOffset = self.amount * sin(self.jiggleTime)

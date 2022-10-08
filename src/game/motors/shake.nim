import glm
import motor
import ../../scenegraph/node

type Shake = ref object of Motor
  node: Node
  amount: float32
  shakeTime: float
  elapsed: float

proc newShake*(node: Node, amount: float): Shake =
  result = Shake(amount: 2f*amount.float32, node: node)
  result.init()

method update(self: Shake, elapsed: float) =
  self.shakeTime += 40f * elapsed
  self.elapsed += elapsed
  self.node.shakeOffset = vec2(self.amount * cos(self.shakeTime.float32 + 0.3f), self.amount * sin(self.shakeTime.float32))

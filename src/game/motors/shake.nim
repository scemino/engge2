import glm
import motor
import ../../scenegraph/node

type Shake = ref object of Motor
    node: Node
    duration: float
    amount: float32
    shakeTime: float
    elapsed: float

proc newShake*(duration: float, node: Node, amount: float): Shake =
  new(result)
  result.node = node
  result.amount = amount.float32
  result.duration = duration
  result.init()

method update(self: Shake, elapsed: float) =
  self.shakeTime += 40f * elapsed
  self.elapsed += elapsed
  self.node.offset = vec2(self.amount * cos(self.shakeTime.float32 + 0.3f), self.amount * sin(self.shakeTime.float32))
  if self.elapsed > self.duration:
    self.disable()

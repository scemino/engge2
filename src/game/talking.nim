import motor
import ../scenegraph/node

type Talking = ref object of Motor
    node: Node
    duration: float

proc newTalking*(node: Node, duration: float): Talking =
  new(result)
  result.node = node
  result.duration = duration
  result.enabled = true

method update(self: Talking, el: float) =
  self.duration -= el
  if self.duration <= 0:
    self.node.remove()
    self.enabled = false
  
import motor
import room
import glm
import utils
import ../script/squtils
import ../scenegraph/node

type WalkTo = ref object of Motor
    obj: Object
    dest: Vec2f

proc newWalkTo*(obj: Object, dest: Vec2f): WalkTo =
  new(result)
  result.obj = obj
  result.dest = dest
  result.enabled = true
  obj.play("walk", true)

proc actorArrived(self: WalkTo) =
  # TODO: actor should have the correct facing
  self.obj.play("stand")
  if rawExists(self.obj.table, "actorArrived"):
    call(self.obj.table, "actorArrived")

method update(self: WalkTo, el: float) =
  let d = distance(self.dest, self.obj.node.pos)
  let delta = self.dest - self.obj.node.pos
  let walkspeed = self.obj.walkSpeed * el
  var dx, dy: float
  if d < 1.0:
    self.enabled = false
    self.actorArrived()
  else:
    if delta.x > 0.0:
      dx = min(walkspeed.x, delta.x)
    else:
      dx = -min(walkspeed.x, -delta.x)
    if delta.y > 0.0:
      dy = min(walkspeed.y, delta.y)
    else:
      dy = -min(walkspeed.y, -delta.y)
    self.obj.node.pos += vec2(dx.float32, dy.float32)
  
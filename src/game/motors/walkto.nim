import glm
import motor
import ../room
import ../../util/utils
import ../../script/squtils
import ../../scenegraph/node

type WalkTo = ref object of Motor
    obj: Object
    path: seq[Vec2f]

proc newWalkTo*(obj: Object, dest: Vec2f): WalkTo =
  new(result)
  result.obj = obj
  result.path = obj.room.calculatePath(obj.node.pos, dest)
  result.enabled = true
  obj.play("walk", true)

proc actorArrived(self: WalkTo) =
  # TODO: actor should have the correct facing
  self.obj.play("stand")
  if rawExists(self.obj.table, "actorArrived"):
    call(self.obj.table, "actorArrived")

method update(self: WalkTo, el: float) =
  var dest = self.path[0]
  let d = distance(dest, self.obj.node.pos)
  let delta = dest - self.obj.node.pos
  let walkspeed = self.obj.walkSpeed * el
  var dx, dy: float
  if d < 1.0:
    self.path.delete 0
    if self.path.len == 0:
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
  
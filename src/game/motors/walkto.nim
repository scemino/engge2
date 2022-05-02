import std/logging
import std/strformat
import std/options
import glm
import motor
import ../room
import ../../util/utils
import ../../script/squtils
import ../../scenegraph/node

type WalkTo = ref object of Motor
    obj: Object
    path: seq[Vec2f]
    facing: Option[Facing]

proc newWalkTo*(obj: Object, dest: Vec2f; facing = none(Facing)): WalkTo =
  new(result)
  result.obj = obj
  result.path = obj.room.calculatePath(obj.node.pos, dest)
  result.enabled = true
  result.facing = facing
  obj.play("walk", true)

proc actorArrived(self: WalkTo) =
  # TODO: actor should have the correct facing
  self.obj.play("stand")
  if self.facing.isSome:
    info fmt"actor arrived with facing {self.facing.get}"
    self.obj.setFacing self.facing.get
  else:
    info fmt"actor arrived with no facing"
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
    if abs(delta.x) >= 0.1:
      self.obj.setFacing(if delta.x >= 0: FACE_RIGHT else: FACE_LEFT)
    else:
      self.obj.setFacing(if delta.y > 0: FACE_BACK else: FACE_FRONT)

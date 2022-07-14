import std/logging
import std/strformat
import std/options
import glm
import motor
import ../engine
import ../verb
import ../room
import ../../util/vecutils
import ../../script/squtils
import ../../scenegraph/node

const
  MIN_USE_DIST  = 5
  MIN_TALK_DIST = 60

type WalkTo = ref object of Motor
    obj: Object
    path: seq[Vec2f]
    facing: Option[Facing]

proc newWalkTo*(obj: Object, dest: Vec2f; facing = none(Facing)): WalkTo =
  new(result)
  result.obj = obj
  result.path = obj.room.calculatePath(obj.node.pos, dest)
  result.facing = facing
  result.init()

proc min_talk_dist(self: Object): int =
  MIN_TALK_DIST

proc min_use_dist(self: Object): int =
  if self.table.rawexists("useDist"):
    self.table.getf("useDist", result)
    info fmt"obj {self.name}: {result}"
  else:
    result = MIN_USE_DIST
    info fmt"obj {self.name}: {result}"

proc verbNotClose(id: VerbId): bool =
  ## true of you don't have to be close to the object
  id == VERB_LOOKAT

proc cantReach(self: Object) =
  if self.table.rawexists("verbCantReach"):
    self.table.call("verbCantReach")

proc actorArrived(self: WalkTo) =
  info "actorArrived"
  self.obj.play("stand")
  # the faces to the specified direction (if any)
  if self.facing.isSome:
    info fmt"actor arrived with facing {self.facing.get}"
    self.obj.setFacing self.facing.get

  # call `actorArrived` callback
  if self.obj.table.rawExists("actorArrived"):
    info "call actorArrived callback"
    self.obj.table.call("actorArrived")
  
  # we need to execute a sentence when arrived ?
  if not self.obj.exec.isNil:
    info "actorArrived: exec sentence"
    if not self.obj.exec.noun1.inInventory:
      # Object became untouchable as we were walking there
      if not self.obj.exec.noun1.touchable:
        info "actorArrived: noun1 untouchable"
        self.obj.exec = nil
        return
      # Did we get close enough?
      let dist = distance(self.obj.node.pos, self.obj.exec.noun1.getUsePos)
      let min_dist = if self.obj.exec.verb == VERB_TALKTO: self.obj.exec.noun1.min_talk_dist else: self.obj.exec.noun1.min_use_dist
      info fmt"actorArrived: noun1 min_dist: {dist} > {min_dist} ?"
      if not verbNotClose(self.obj.exec.verb) and dist > min_dist.float:
        self.obj.cantReach()
        return
      self.obj.setFacing(self.obj.exec.noun1.useDir.facing)
    if not self.obj.exec.noun2.isNil and not self.obj.exec.noun2.inInventory:
      if not self.obj.exec.noun2.touchable:
        # Object became untouchable as we were walking there.
        info "actorArrived: noun2 untouchable"
        self.obj.exec = nil
        return
      let dist = distance(self.obj.node.pos, self.obj.exec.noun2.getUsePos)
      let min_dist = if self.obj.exec.verb == VERB_TALKTO: self.obj.exec.noun2.min_talk_dist else: self.obj.exec.noun2.min_use_dist
      info fmt"actorArrived: noun2 min_dist: {dist} > {min_dist} ?"
      if dist > min_dist.float:
        self.obj.cantReach()
        return
    
    info fmt"actorArrived: callVerb"
    discard gEngine.callVerb(self.obj, self.obj.exec.verb, self.obj.exec.noun1, self.obj.exec.noun2)
    self.obj.exec = nil

method update(self: WalkTo, el: float) =
  var dest = self.path[0]
  let d = distance(dest, self.obj.node.pos)
  let delta = dest - self.obj.node.pos
  let walkspeed = self.obj.walkSpeed * el
  var dx, dy: float
  if d < 1.0:
    self.path.delete 0
    if self.path.len == 0:
      self.disable()
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

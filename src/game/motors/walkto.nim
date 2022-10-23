import std/logging
import std/strformat
import std/options
import glm
import motor
import sqnim
import ../actoranim
import ../engine
import ../verb
import ../room
import ../../game/ids
import ../../util/vecutils
import ../../script/squtils
import ../../script/vm
import ../../scenegraph/node
import ../../util/common
import ../../script/scriptconsts

const
  MIN_USE_DIST  = 10
  MIN_TALK_DIST = 60

type ReachAnim* = ref object of Motor
    actor: Object
    obj: Object
    state: int
    elapsed: float

type WalkTo* = ref object of Motor
    obj: Object
    path*: seq[Vec2f]
    facing: Option[Facing]
    wsd: float32
    reach: ReachAnim

proc newReachAnim*(actor, obj: Object): ReachAnim =
  result = ReachAnim(actor: actor, obj: obj)
  result.init()

proc getReachAnim(obj: Object): string =
  let flags = obj.getFlags()
  if flags.hasFlag(REACH_LOW):
    result = "_low"
  elif flags.hasFlag(REACH_HIGH):
    result = "_high"
  else:
    result = "_med"

proc playReachAnim(self: ReachAnim) =
  let anim = self.actor.getAnimName(ReachAnimName & self.obj.getReachAnim())
  self.actor.play(anim)
  discard

proc execVerb(self: Object)

method update(self: ReachAnim, el: float) =
  case self.state:
  of 0:
    self.playReachAnim()
    self.state = 1
  of 1:
    self.elapsed += el
    if self.elapsed > 0.5:
      self.state = 2
  of 2:
    self.actor.stand()
    self.actor.execVerb()
    self.disable()
    self.state = 3
  else:
    discard

proc newWalkTo*(obj: Object, dest: Vec2f; facing = none(Facing)): WalkTo =
  let path = if obj.useWalkboxes: obj.room.calculatePath(obj.node.pos, dest) else: @[obj.node.pos, dest]
  let wsd = sqrt(obj.walkspeed.x * obj.walkspeed.x + obj.walkspeed.y * obj.walkspeed.y)
  result = WalkTo(obj: obj, path: path, wsd: wsd, facing: facing)
  result.init()
  if obj.table.rawexists("preWalking"):
    sqCall(obj.table, "preWalking", [])

proc min_talk_dist(self: Object): int =
  MIN_TALK_DIST

proc min_use_dist(self: Object): int =
  if self.table.rawexists("useDist"):
    self.table.getf("useDist", result)
    info fmt"useDist obj {self.name}: {result}"
  else:
    result = MIN_USE_DIST
    info fmt"useDist obj {self.name}: {result}"

proc verbNotClose(id: VerbId): bool =
  ## true of you don't have to be close to the object
  id == VERB_LOOKAT

proc cantReach(self: Object, noun2: Object) =
  if self.table.exists("verbCantReach"):
    let nParams = gVm.v.paramCount(self.table, "verbCantReach")
    info fmt"verbCantReach found in obj '{self.key}' with {nParams} params"
    if nParams == 1:
      self.table.call("verbCantReach")
    else:
      var table: HSQOBJECT
      sq_resetobject(table)
      if not noun2.isNil:
        table = noun2.table
      self.table.sqCall("verbCantReach", [self.table, table])
  elif not noun2.isNil:
    noun2.cantReach(nil)
  else:
    var nilTbl: HSQOBJECT
    gEngine.defaultObj.call("verbCantReach", [self.table, if noun2.isnil: nilTbl else: noun2.table])

proc execVerb(self: Object) =
  if not self.exec.isNil:
    let verb = self.exec.verb
    let noun1 = self.exec.noun1
    let noun2 = self.exec.noun2

    info "actorArrived: exec sentence"
    if not noun1.inInventory:
      # Object became untouchable as we were walking there
      if not noun1.touchable:
        info "actorArrived: noun1 untouchable"
        self.exec = nil
        return
      # Did we get close enough?
      let dist = distance(self.getUsePos, noun1.getUsePos)
      let min_dist = if verb == VERB_TALKTO: noun1.min_talk_dist else: noun1.min_use_dist
      info fmt"actorArrived: noun1 min_dist: {dist} > {min_dist} (actor: {self.getUsePos}, obj: {noun1.getUsePos}) ?"
      if not verbNotClose(verb) and dist > min_dist.float:
        self.cantReach(noun2)
        return
      if noun1.useDir != dNone:
        self.setFacing(noun1.useDir.facing)
    if not noun2.isNil and not noun2.inInventory:
      if not noun2.touchable:
        # Object became untouchable as we were walking there.
        info "actorArrived: noun2 untouchable"
        self.exec = nil
        return
      let dist = distance(self.getUsePos, noun2.getUsePos)
      let min_dist = if verb == VERB_TALKTO: noun2.min_talk_dist else: noun2.min_use_dist
      info fmt"actorArrived: noun2 min_dist: {dist} > {min_dist} ?"
      if dist > min_dist.float:
        self.cantReach(noun2)
        return

    info fmt"actorArrived: callVerb"
    self.exec = nil
    discard gEngine.callVerb(self, verb, noun1, noun2)

proc needsReachAnim(verbId: int): bool =
  verbId == VERB_PICKUP or verbId == VERB_OPEN or verbId == VERB_CLOSE or verbId == VERB_PUSH or verbId == VERB_PULL or verbId == VERB_USE

proc actorArrived(self: WalkTo) =
  let needsReach = not self.obj.exec.isNil and needsReachAnim(self.obj.exec.verb)
  if not needsReach:
    self.disable()

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
    let verb = self.obj.exec.verb
    let noun1 = self.obj.exec.noun1
    let noun2 = self.obj.exec.noun2
    # call `postWalk`callback
    let funcName = if noun1.id.isActor: "actorPostWalk" else: "objectPostWalk"
    if self.obj.table.rawExists(funcName):
      info fmt"call {funcName} callback"
      var n2Table: HSQOBJECT
      if not noun2.isNil:
        n2Table = noun2.table
      else:
        sq_resetobject(n2Table)
      sqCall(self.obj.table, funcName, [verb, noun1.table, n2Table])

    if needsReach:
      self.reach = newReachAnim(self.obj, noun1)
    else:
      self.obj.execVerb()

method disable*(self: WalkTo) =
  procCall self.Motor.disable()
  if self.path.len != 0:
    info "actor walk cancelled"
  self.obj.play("stand")

method update(self: WalkTo, el: float) =
  if self.path.len != 0:
    let dest = self.path[0]
    let d = distance(dest, self.obj.node.pos)

    # arrived at destination ?
    if d < 1.0:
      self.obj.node.pos = self.path[0]
      self.path.delete 0
      if self.path.len == 0:
        self.actorArrived()
    else:
      let delta = dest - self.obj.node.pos
      let duration = d / self.wsd
      let factor = clamp(el / duration, 0f, 1f)

      let dd = delta * factor
      self.obj.node.pos += dd
      if abs(delta.x) >= abs(delta.y):
        self.obj.setFacing(if delta.x >= 0: FACE_RIGHT else: FACE_LEFT)
      else:
        self.obj.setFacing(if delta.y > 0: FACE_BACK else: FACE_FRONT)
  if not self.reach.isNil and self.reach.enabled:
    self.reach.update(el)
    if not self.reach.enabled:
      self.disable()

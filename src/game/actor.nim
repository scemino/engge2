import std/json
import std/options
import std/tables
import std/strformat
import glm
import sqnim
import nimyggpack
import room
import ids
import ../script/squtils
import ../io/ggpackmanager
import ../gfx/spritesheet
import ../gfx/color
import resmanager
import objanim
import motors/walkto
import motors/blink

const
  StandAnimName = "stand"
  HeadAnimName  = "head"
  WalkAnimName  = "walk"
  ReachAnimName = "reach"

proc getFacing(dir: Direction): Facing =
  case dir:
  of dRight: FACE_RIGHT
  of dLeft:  FACE_LEFT
  of dFront: FACE_FRONT
  of dBack:  FACE_BACK
  else: 
      FACE_RIGHT

proc animName*(self: Object, key: string): string

proc setHeadIndex*(self: Object, head: int) =
  for i in 1..6:
    self.showLayer(fmt"{self.animName(HeadAnimName)}{i}", i == head)

proc newActor*(): Object =
  result = newObject(FACE_FRONT)
  result.table.setId newActorId()
  result.showLayer("blink", false)
  result.showLayer("eyes_left", false)
  result.showLayer("eyes_right", false)
  result.setHeadIndex(1)

proc getName*(self: Object): string =
  getf(self.table, "name", result)

proc animName(self: Object, key: string): string =
  if self.animNames.contains(key):
    result = self.animNames[key]
  else:
    result = key

proc stand*(self: Object) =
  self.play(self.animName(StandAnimName))

proc setAnimationNames*(self: Object, head, stand, walk, reach: string) =
  if head.len > 0:
    self.animNames[HeadAnimName] = head
  if stand.len > 0:
    self.animNames[StandAnimName] = stand
  if walk.len > 0:
    self.animNames[WalkAnimName] = walk
  if reach.len > 0:
    self.animNames[ReachAnimName] = reach

proc setCostume*(self: Object, name, sheet: string) =
  let stream = gGGPackMgr.loadStream(name & ".json")
  let json = newGGTableDecoder(stream).hash
  self.anims = parseObjectAnimations(json["animations"])
  var path = if sheet.len == 0: json["sheet"].str else: sheet 
  self.sheet = path
  self.stand()

proc walk*(self: Object, pos: Vec2f; facing = none(Facing)) =
  ## Walks an actor to the `pos` or actor `obj` and then faces `dir`.
  self.play(WalkAnimName, true)
  self.walkTo = newWalkTo(self, pos, facing)

proc walk*(self: Object, obj: Object) =
  ## Walks an actor to the `obj` and then faces it. 
  self.walk(obj.node.pos + obj.usePos, some(getFacing(obj.useDir)))

import motors/talking

proc say(self: var TalkingState, texts: seq[string], obj: Object) =
  self.obj.talking = newTalking(self.obj, texts, self.color)

proc say*(self: Object, texts: seq[string], color: Color) =
  self.talkingState.obj = self
  self.talkingState.color = color
  self.talkingState.say(texts, self)

proc blinkRate*(self: Object, slice: HSlice[float, float]) =
  if slice.a == 0.0 and slice.b == 0.0:
    self.blink = nil
  else:
    self.blink = newBlink(self, slice)

proc pickupObject*(self: Object, obj: Object) =
  obj.owner = self
  self.inventory.add obj

  call("onPickup", [obj.table, self.table])

  if obj.table.rawexists("onPickUp"):
    obj.table.call("onPickUp", [self.table])

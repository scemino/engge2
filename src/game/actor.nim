import std/json
import std/options
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
import motors/talking
import motors/walkto

proc newActor*(): Object =
  result = newObject(FACE_FRONT)
  result.table.setId newActorId()
  result.showLayer("blink", false)
  result.showLayer("eyes_left", false)
  result.showLayer("eyes_right", false)
  result.setHeadIndex(1)

proc getName*(self: Object): string =
  getf(self.table, "name", result)

proc setCostume*(self: Object, name, sheet: string) =
  let stream = gGGPackMgr.loadStream(name & ".json")
  let json = newGGTableDecoder(stream).hash
  self.anims = parseObjectAnimations(json["animations"])
  var path = if sheet.len == 0: json["sheet"].str else: sheet 
  self.spriteSheet = gResMgr.spritesheet(path)
  self.texture = gResMgr.texture(self.spriteSheet.meta.image)
  self.play("stand")

proc walk*(self: Object, dest: Vec2f; facing = none(Facing)) =
  self.walkTo = newWalkTo(self, dest, facing)

proc say(self: var TalkingState, texts: seq[string], obj: Object) =
  self.obj.talking = newTalking(self.obj, texts, self.color)

proc say*(self: Object, texts: seq[string], color: Color) =
  self.talkingState.obj = self
  self.talkingState.color = color
  self.talkingState.say(texts, self)

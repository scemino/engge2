import std/json
import std/parseutils
import std/strformat
import std/logging
import glm
import sqnim
import nimyggpack
import room
import engine
import ../script/squtils
import ../io/ggpackmanager
import ../gfx/spritesheet
import ../gfx/text
import ../gfx/color
import ../gfx/graphics
import ../scenegraph/node
import ../scenegraph/textnode
import ../audio/audio
import ../io/lip
import ../io/textdb
import resmanager
import objanim
import motors/talking
import motors/walkto

proc newActor*(): Object =
  result = Object(facing: FACE_FRONT)
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

proc walk*(self: Object, dest: Vec2f) =
  self.walkTo = newWalkTo(self, dest)

proc roomToScreen*(pos: Vec2f): Vec2f =
  let screenSize = gEngine.room.getScreenSize()
  vec2(1280f, 720f) * (pos - cameraPos()) / vec2(screenSize.x.float32, screenSize.y.float32)

proc onTalkieId(self: TalkingState, id: int): int =
  var idObj: HSQOBJECT
  idObj.objType = OT_INTEGER
  idObj.value.nInteger = id
  callFunc(result, self.obj.table, "onTalkieID", [idObj])
  if result == 0:
    result = id

proc talkieKey(self: TalkingState): string =
  if rawexists(self.obj.table, "_talkieKey"):
    getf(self.obj.table, "_talkieKey", result)
  else:
    getf(self.obj.table, "_key", result)

proc loadActorSpeech(self: TalkingState, name: string): SoundId =
  info fmt"loadActorSpeech {name}.ogg"
  var soundDefinition = newSoundDefinition(name & ".ogg")
  gEngine.audio.soundDefs.add(soundDefinition)
  if soundDefinition.isNil:
    error fmt"File {name}.ogg not found"
  else:
    # TODO: add actor id
    result = gEngine.audio.play(soundDefinition, scTalk)

proc say(self: var TalkingState, texts: seq[string], obj: Object) =
  # TODO: process other texts
  var txt = texts[0]
  var lip: Lip
  var soundId: SoundId
  if txt.len > 0:
    if txt[0] == '@':
      var id: int
      discard parseInt(txt, id, 1)
      id = self.onTalkieId(id)
      txt = getText(id)

      var name = fmt"{self.talkieKey()}_{id}"
      var path = name & ".lip"

      # TODO: actor animation
      if gGGPackMgr.assetExists(path):
        lip = newLip(path)

      # TODO: call sayingLine
      soundId = self.loadActorSpeech(name)

    self.obj.sayNode.remove()
    var text = newText(gResMgr.font("sayline"), txt, taCenter, 600, self.color)
    self.obj.sayNode = newTextNode text
    var pos = roomToScreen(self.obj.node.pos + vec2(self.obj.talkOffset.x.float32, self.obj.talkOffset.y.float32))
    # clamp position to keep it on screen
    pos.x = clamp(pos.x, 10f + text.bounds.x / 2f, 1280f - text.bounds.x / 2f)
    pos.y = clamp(pos.y, 10f + text.bounds.y.float32, 720f - text.bounds.y.float32)
    self.obj.sayNode.pos = pos
    self.obj.sayNode.setAnchorNorm(vec2(0.5f, 0.5f))
    gEngine.screen.addChild self.obj.sayNode
    self.obj.talking = newTalking(self.obj, lip, soundId)

proc say*(self: Object, texts: seq[string], color: Color) =
  self.talkingState.obj = self
  self.talkingState.color = color
  self.talkingState.say(texts, self)

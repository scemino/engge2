import std/tables
import std/logging
import std/strformat
import std/strutils
import std/parseutils
import glm
import sqnim
import motor
import ../../scenegraph/node
import ../../scenegraph/textnode
import ../../game/engine
import ../../game/room
import ../../game/resmanager
import ../../game/screen
import ../../io/lip
import ../../io/textdb
import ../../io/ggpackmanager
import ../../audio/audio
import ../../gfx/text
import ../../gfx/color
import ../../script/squtils

const letterToIndex = {'A': 1, 'B': 2, 'C': 3, 'D': 4, 'E': 5, 'F': 6, 'G': 1 ,'H': 4, 'X': 1}.toTable

type Talking = ref object of Motor
  obj: Object
  node: Node
  lip: Lip
  elapsed: float
  soundId: SoundId
  color: Color
  texts: seq[string]

proc onTalkieId(self: Talking, id: int): int =
  var idObj: HSQOBJECT
  idObj.objType = OT_INTEGER
  idObj.value.nInteger = id
  callFunc(self.obj.table, result, "onTalkieID", [idObj])
  if result == 0:
    result = id

proc talkieKey(self: Talking): string =
  if rawexists(self.obj.table, "_talkieKey"):
    getf(self.obj.table, "_talkieKey", result)
  else:
    getf(self.obj.table, "_key", result)

proc loadActorSpeech(self: Talking, name: string): SoundId =
  info fmt"loadActorSpeech {name}.ogg"
  let soundDefinition = newSoundDefinition(name.toUpper & ".ogg")
  gEngine.audio.soundDefs.add(soundDefinition)
  if soundDefinition.isNil:
    error fmt"File {name}.ogg not found"
  else:
    # TODO: add actor id
    result = gEngine.audio.play(soundDefinition, Talk)
    
proc say(self: Talking, text: string) =
  info fmt"sayLine {text}"
  var txt = text
  if text[0] == '@':
    var id: int
    discard parseInt(text, id, 1)
    id = self.onTalkieId(id)
    txt = getText(id)

    var name = fmt"{self.talkieKey()}_{id}"
    var path = name & ".lip"

    # TODO: actor animation
    if gGGPackMgr.assetExists(path):
      self.lip = newLip(path)

    # TODO: call sayingLine
    self.soundId = self.loadActorSpeech(name)

  self.obj.sayNode.remove()
  var text = newText(gResMgr.font("sayline"), txt, taCenter, ScreenWidth*3f/4f, self.color)
  self.obj.sayNode = newTextNode text
  self.node = self.obj.sayNode
  var pos = gEngine.room.roomToScreen(self.obj.node.pos + vec2(self.obj.talkOffset.x.float32, self.obj.talkOffset.y.float32))
  # clamp position to keep it on screen
  pos.x = clamp(pos.x, 10f + text.bounds.x / 2f, ScreenWidth - text.bounds.x / 2f)
  pos.y = clamp(pos.y, 10f + text.bounds.y.float32, ScreenHeight - text.bounds.y.float32)
  self.obj.sayNode.pos = pos
  self.obj.sayNode.setAnchorNorm(vec2(0.5f, 0.5f))
  gEngine.screen.addChild self.obj.sayNode

proc newTalking*(obj: Object, texts: seq[string], color: Color): Talking =
  ## Creates a talking animation for a specified object.
  new(result)
  result.obj = obj
  result.color = color
  result.texts = texts[1..^1]
  result.say(texts[0])
  result.init()

import ../actor

method disable(self: Talking) =
  procCall self.Motor.disable()
  self.texts.setLen 0
  self.obj.setHeadIndex(1)
  self.node.remove()

method update(self: Talking, el: float) =
  if gEngine.audio.playing(self.soundId):
    var letter = self.lip.letter(self.elapsed)
    self.elapsed += el
    self.obj.setHeadIndex(letterToIndex[letter])
  else:
    if self.texts.len > 0:
      self.elapsed = 0
      self.say(self.texts[0])
      self.texts.del 0
    else:
      self.disable()
  
import std/tables
import std/logging
import std/strformat
import std/strutils
import std/parseutils
import glm
import sqnim
import motor
import ../actoranim
import ../../scenegraph/node
import ../../scenegraph/textnode
import ../../game/engine
import ../../game/room
import ../../game/resmanager
import ../../game/screen
import ../../game/prefs
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
  elapsed, duration: float
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
  let filename = name.toUpper & ".ogg"
  if gGGPackMgr.assetExists(filename):
    let soundDefinition = newSoundDefinition(filename)
    if soundDefinition.isNil:
      error fmt"File {name}.ogg not found"
    else:
      gEngine.audio.soundDefs.add(soundDefinition)
      # TODO: add actor id
      result = gEngine.audio.play(soundDefinition, Talk)

proc setDuration(self: Talking, text: string) =
  self.elapsed = 0
  let sayLineBaseTime = prefs(SayLineBaseTime)
  let sayLineCharTime = prefs(SayLineCharTime)
  let sayLineMinTime = prefs(SayLineMinTime)
  let sayLineSpeed = prefs(SayLineSpeed)
  let duration = (sayLineBaseTime + sayLineCharTime * text.len.float32) / (0.2f + sayLineSpeed)
  self.duration = max(duration, sayLineMinTime)

proc say(self: Talking, text: string) =
  var txt = text
  if text[0] == '@':
    var id: int
    discard parseInt(text, id, 1)
    id = self.onTalkieId(id)
    txt = getText(id)

    let name = fmt"{self.talkieKey().toUpper()}_{id}"
    let path = name & ".lip"

    info fmt"Load lip {path}"
    if gGGPackMgr.assetExists(path):
      self.lip = newLip(path)
      info fmt"Lip {path} loaded: {self.lip}"

    # TODO: call sayingLine
    self.soundId = self.loadActorSpeech(name)
  elif text[0] == '^':
    txt = text[1..^1]

  # remove text in parenthesis
  if txt[0] == '(':
    let i = txt.find(')')
    if i != -1:
      txt = txt[i+1..^1]

  info fmt"sayLine '{txt}'"

  # modify state ?
  var state: string
  if txt[0] == '{':
    let i = txt.find('}')
    if i != -1:
      state = txt[1..i-1]
      info fmt"Set state from anim '{state}'"
      if state != "notalk":
        self.obj.play(state)
      txt = txt[i + 1..^1]

  self.setDuration(txt)

  self.obj.sayNode.remove()
  let text = newText(gResMgr.font("sayline"), txt, thCenter, tvCenter, ScreenWidth*3f/4f, self.color)
  self.obj.sayNode = newTextNode text
  self.obj.sayNode.color = self.color
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

method update(self: Talking, elapsed: float) =
  if self.enabled:
    self.elapsed += elapsed
    if self.elapsed < self.duration:
      let letter = self.lip.letter(self.elapsed)
      self.obj.setHeadIndex(letterToIndex[letter])
    else:
      if self.texts.len > 0:
        self.say(self.texts[0])
        self.texts.del 0
      else:
        self.disable()

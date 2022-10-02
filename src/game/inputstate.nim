
import std/tables
import glm
import resmanager
import ../gfx/color
import ../gfx/graphics
import ../gfx/spritesheet
import ../gfx/texture
import ../gfx/recti
import ../gfx/text
import ../game/screen
import ../game/prefs
import ../scenegraph/node

type
  InputStateFlag* {.pure, size: int32.sizeof.} = enum
    UI_INPUT_ON = 1.cint
    UI_INPUT_OFF = 2.cint
    UI_VERBS_ON = 4.cint
    UI_VERBS_OFF = 8.cint
    UI_HUDOBJECTS_ON = 0x10.cint
    UI_HUDOBJECTS_OFF = 0x20.cint
    UI_CURSOR_ON = 0x40.cint
    UI_CURSOR_OFF = 0x80.cint
  CursorShape* = enum
    Normal
    Front,
    Back,
    Left,
    Right,
    Pause
  InputState* = ref object of Node
    inputHUD*: bool
    inputActive*: bool
    showCursor*: bool
    inputVerbsActive*: bool
    cursorShape: CursorShape
    cursorName: string
    hotspot*: bool
  Sentence* = ref object of Node
    text: string

const 
  CursorShapeNames = {Normal: "cursor", Left: "cursor_left", Right: "cursor_right", Front: "cursor_front", Back: "cursor_back", Pause: "cursor_pause"}.toTable
  Margin = 60f

var gInputNode*: Node

proc newInputState*(): InputState =
  result = InputState(showCursor: true, cursorName: "cursor", zOrder: -100)
  result.init()
  gInputNode = result

proc setCursorShape*(self: InputState, shape: CursorShape) =
  if self.cursorShape != shape:
    self.cursorShape = shape
    self.cursorName = CursorShapeNames[shape]

proc setState*(self: InputState, state: InputStateFlag) =
  if (UI_INPUT_ON.cint and state.cint) == UI_INPUT_ON.cint:
    self.inputActive = true
  if (UI_INPUT_OFF.cint and state.cint) == UI_INPUT_OFF.cint:
    self.inputActive = false;
  if (UI_VERBS_ON.cint and state.cint) == UI_VERBS_ON.cint:
    self.inputVerbsActive = true
  if (UI_VERBS_OFF.cint and state.cint) == UI_VERBS_OFF.cint:
    self.inputVerbsActive = false
  if (UI_CURSOR_ON.cint and state.cint) == UI_CURSOR_ON.cint:
    self.showCursor = true
    self.visible = true
  if (UI_CURSOR_OFF.cint and state.cint) == UI_CURSOR_OFF.cint:
    self.showCursor = false
    self.visible = false
  if (UI_HUDOBJECTS_ON.cint and state.cint) == UI_HUDOBJECTS_ON.cint:
    self.inputHUD = true
  if (UI_HUDOBJECTS_OFF.cint and state.cint) == UI_HUDOBJECTS_OFF.cint:
    self.inputHUD = false

proc getState*(self: InputState): InputStateFlag =
  var tmp: cint
  tmp += (if self.inputActive: UI_INPUT_ON.cint else: UI_INPUT_OFF.cint)
  tmp += (if self.inputVerbsActive: UI_VERBS_ON.cint else: UI_VERBS_OFF.cint)
  tmp += (if self.showCursor: UI_CURSOR_ON.cint else: UI_CURSOR_OFF.cint)
  tmp += (if self.inputHUD: UI_HUDOBJECTS_ON.cint else: UI_HUDOBJECTS_OFF.cint)
  cast[InputStateFlag](tmp)

proc drawSprite(sf: SpriteSheetFrame, texture: Texture, color: Color, transf: Mat4f) =
  let pos = vec3f(sf.spriteSourceSize.x.float32 - sf.sourceSize.x.float32 / 2f,  - sf.spriteSourceSize.h.float32 - sf.spriteSourceSize.y.float32 + sf.sourceSize.y.float32 / 2f, 0f)
  let trsf = translate(transf, pos)
  gfxDrawSprite(sf.frame / texture.size, texture, color, trsf)

method drawCore(self: InputState, transf: Mat4f) =
  # draw cursor
  let gameSheet = gResMgr.spritesheet("GameSheet")
  let texture = gResMgr.texture(gameSheet.meta.image)
  var cursorName = self.cursorName
  if prefs(ClassicSentence) and self.hotspot:
      cursorName = "hotspot_" & self.cursorName
  let frame = gameSheet.frame(cursorName)
  drawSprite(frame, texture, self.color, scale(transf, vec3(2f, 2f, 1f)))

proc newSentence*(): Sentence =
  result = Sentence()
  result.init()

proc setText*(self: Sentence, text: string) =
  self.text = text

method drawCore(self: Sentence, transf: Mat4f) =
  let text = newText(gResMgr.font("sayline"), self.text)
  var x, y: float32
  if prefs(ClassicSentence):
    x = (ScreenWidth - text.bounds.x) / 2f
    y = 208f
  else:
    x = max(self.pos.x - text.bounds.x/2f, Margin)
    x = min(x, ScreenWidth - text.bounds.x - Margin)
    y = self.pos.y + 2f*38f
    if y >= ScreenHeight:
      y = self.pos.y - 38f
  let t = translate(mat4(1f), vec3(x, y, 0f))
  text.draw(t)
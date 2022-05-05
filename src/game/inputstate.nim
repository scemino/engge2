
import std/tables
import glm
import resmanager
import ../gfx/spritesheet
import ../gfx/text
import ../scenegraph/node
import ../scenegraph/textnode
import ../scenegraph/spritenode

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
  InputState* = object
    inputHUD*: bool
    inputActive*: bool
    showCursor*: bool
    inputVerbsActive*: bool
    node*: Node
    cursorNode: SpriteNode
    text: Text
    textNode: TextNode

proc newInputState*(): InputState =
  result = InputState(showCursor: true)
  var gameSheet = gResMgr.spritesheet("GameSheet")
  var texture = gResMgr.texture(gameSheet.meta.image)
  var frame = gameSheet.frames["cursor"]
  result.node = newNode("input")
  result.cursorNode = newSpriteNode(texture, frame)
  result.cursorNode.scale = vec2(2f, 2f)
  result.text = newText(gResMgr.font("sayline"), "", taCenter)
  result.textNode = newTextNode(result.text)
  result.node.addChild result.cursorNode
  result.node.addChild result.textNode
  result.textNode.offset = vec2(0f, frame.sourceSize.y.float32)
  result.textNode.setAnchorNorm(vec2(0.5f, 1f))

proc setText*(self: var InputState, text: string) =
  self.text.text = text
  self.textNode.updateBounds()

proc setState*(self: var InputState, state: InputStateFlag) =
  if (UI_INPUT_ON.cint and state.cint) == UI_INPUT_ON.cint:
    self.inputActive = true
  if (UI_INPUT_OFF.cint and state.cint) == UI_INPUT_OFF.cint:
    self.inputActive = false;
  if (UI_VERBS_ON.cint and state.cint) == UI_VERBS_ON.cint:
    self.inputVerbsActive = true
  if (UI_VERBS_OFF.cint and state.cint) == UI_VERBS_OFF.cint:
    self.inputVerbsActive = false
  if (UI_CURSOR_ON.cint and state.cint) == UI_CURSOR_ON.cint:
    self.showCursor = true;
  if (UI_CURSOR_OFF.cint and state.cint) == UI_CURSOR_OFF.cint:
    self.showCursor = false
  if (UI_HUDOBJECTS_ON.cint and state.cint) == UI_HUDOBJECTS_ON.cint:
    self.inputHUD = true
  if (UI_HUDOBJECTS_OFF.cint and state.cint) == UI_HUDOBJECTS_OFF.cint:
    self.inputHUD = false

proc getState*(self: var InputState): InputStateFlag =
  var tmp: cint
  tmp += (if self.inputActive: UI_INPUT_ON.cint else: UI_INPUT_OFF.cint)
  tmp += (if self.inputVerbsActive: UI_VERBS_ON.cint else: UI_VERBS_OFF.cint)
  tmp += (if self.showCursor: UI_CURSOR_ON.cint else: UI_CURSOR_OFF.cint)
  tmp += (if self.inputHUD: UI_HUDOBJECTS_ON.cint else: UI_HUDOBJECTS_OFF.cint)
  cast[InputStateFlag](tmp)

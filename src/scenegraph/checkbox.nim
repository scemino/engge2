import glm
import node
import textnode
import spritenode
import ../gfx/text
import ../gfx/color
import ../gfx/spritesheet
import ../game/resmanager
import ../game/screen
import ../io/textdb

type
  CheckCallback* = proc(self: Checkbox, state: bool)
  Checkbox* = ref object of Node
    id*: int
    tag*: pointer
    checked: bool
    checkNode: SpriteNode
    callback: CheckCallback

proc check*(self: Checkbox, state: bool) =
  self.checked = state
  let sheet = gResMgr.spritesheet("SaveLoadSheet")
  self.checkNode.setFrame(sheet.frame(if self.checked: "option_checked" else: "option_unchecked"))

proc onButton(src: Node, event: EventKind, pos: Vec2f, tag: pointer) =
  let checkbox = cast[Checkbox](tag)
  case event:
  of Enter:
    src.getParent().color = Yellow
  of Leave:
    src.getParent().color = White
  of Down:
    checkbox.callback(checkbox, not checkbox.checked)
  else:
    discard

proc newCheckbox*(id: int, y: float, callback: CheckCallback, state = false, tag: pointer = nil): Checkbox =
  result = Checkbox(id: id, callback: callback, checked: state, tag: tag)
  result.init()

  let titleTxt = newText(gResMgr.font("UIFontSmall"), getText(id), thLeft)
  let tn = newTextNode(titleTxt)
  tn.setAnchorNorm(vec2(0f, 0.5f))
  tn.pos = vec2f(420f, 0f)
  result.addChild tn

  let sheet = gResMgr.spritesheet("SaveLoadSheet")
  result.checkNode = newSpriteNode(gResMgr.texture(sheet.meta.image), sheet.frame(if state: "option_checked" else: "option_unchecked"))
  result.check(state)
  result.checkNode.scale = vec2(4f, 4f)
  result.checkNode.pos = vec2f(ScreenWidth - 440f, 0f)
  result.checkNode.addButton(onButton, cast[pointer](result))
  result.addChild result.checkNode

  result.pos.y = y

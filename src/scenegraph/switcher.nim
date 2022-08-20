import glm
import node
import textnode
import ../gfx/text
import ../gfx/color
import ../game/resmanager
import ../game/screen
import ../io/textdb

type
  SwitcherCallback* = proc(self: Switcher, value: int)
  Switcher* = ref object of Node
    tag*: pointer
    text: TextNode
    values: seq[int]
    index: int
    callback: SwitcherCallback

proc onButton(src: Node, event: EventKind, pos: Vec2f, tag: pointer) =
  let switcher = cast[Switcher](tag)
  case event:
  of Enter:
    src.getParent().color = Yellow
  of Leave:
    src.getParent().color = White
  of Down:
    switcher.index = (switcher.index + 1) mod switcher.values.len
    let id = switcher.values[switcher.index]
    switcher.text.text.text = getText(id)
    switcher.text.pos = vec2f(ScreenWidth/2f - switcher.text.text.bounds.x/2f, 0f)
    switcher.callback(switcher, switcher.index)
  else:
    discard

proc newSwitcher*(y: float, callback: SwitcherCallback, values: seq[int], value: int, tag: pointer = nil): Switcher =
  result = Switcher(callback: callback, values: values, index: values.find(value), tag: tag)
  result.init()

  let text = newText(gResMgr.font("UIFontMedium"), getText(value), thCenter)
  result.text = newTextNode(text)
  result.text.pos = vec2f(ScreenWidth/2f - text.bounds.x/2f, 0f)
  result.text.addButton(onButton, cast[pointer](result))
  result.addChild result.text

  result.pos.y = y

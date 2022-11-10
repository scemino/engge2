import glm
import node
import textnode
import ../gfx/text
import ../gfx/color
import ../game/resmanager
import ../game/screen
import ../io/textdb
import ../audio/audio

type
  SwitcherCallback* = proc(self: Switcher, value: int)
  Switcher* = ref object of Node
    tag*: pointer
    text: TextNode
    values: seq[int]
    index: int
    callback: SwitcherCallback

proc onButton(src: Node, event: EventKind, pos: Vec2f, tag: pointer) =
  var switcher = cast[Switcher](tag)
  case event:
  of Enter:
    src.getParent().color = Yellow
    playSoundHover()
  of Leave:
    src.getParent().color = White
  of Down:
    src.getParent().color = White
    switcher.index = (switcher.index + 1) mod switcher.values.len
    let id = switcher.values[switcher.index]
    switcher.text.remove()
    let text = newText(gResMgr.font("UIFontMedium"), getText(id), thCenter)
    switcher.text = newTextNode(text)
    switcher.text.pos = vec2f(ScreenWidth/2f - text.bounds.x/2f, 0f)
    switcher.text.addButton(onButton, cast[pointer](switcher))
    switcher.addChild switcher.text
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

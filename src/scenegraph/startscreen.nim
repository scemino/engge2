import glm
import node
import textnode
import sqnim
import ../gfx/color
import ../gfx/text
import ../game/resmanager
import ../game/screen
import ../io/textdb
import ../script/squtils
import ../script/vm

const
  LoadGame = 99910
  NewGame = 99912
  Options = 99913
  Help = 99961
  Quit = 99915

type
  StartScreen* = ref object of Node

proc onButtonDown(node: Node, id: int) =
  case id:
  of NewGame:
    node.remove()
    sqCall("start", [1])
  of Quit:
    quit()
  else:
    discard

proc onButton(src: Node, event: EventKind, pos: Vec2f, tag: pointer) =
  let id = cast[int](tag)
  case event:
  of Enter:
    src.color = Yellow
  of Leave:
    src.color = White
  of Down:
    onButtonDown(src.getParent, id)
  else:
    discard

proc newLabel(id: int, y: float): TextNode =
  let titleTxt = newText(gResMgr.font("UIFontLarge"), getText(id), thCenter)
  result = newTextNode(titleTxt)
  result.pos = vec2(ScreenWidth/2f - titleTxt.bounds.x/2f, y)
  result.addButton(onButton, cast[pointer](id))

proc newStartScreen*(): StartScreen =
  result = StartScreen()
  result.init()
  result.addChild newLabel(LoadGame, 600f)
  result.addChild newLabel(NewGame, 500f)
  result.addChild newLabel(Options, 400f)
  result.addChild newLabel(Help, 300f)
  result.addChild newLabel(Quit, 200f)

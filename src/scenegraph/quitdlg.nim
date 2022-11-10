import glm
import node
import uinode
import textnode
import spritenode
import ../gfx/color
import ../gfx/graphics
import ../gfx/text
import ../gfx/spritesheet
import ../game/resmanager
import ../game/screen
import ../io/textdb
import ../audio/audio

const
  Yes* = 99907
  No* = 99908
  QuitText = 99909

type
  ClickCallback* = proc(node: Node, id: int)
  QuitDialog* = ref object of UINode
    clickCbk: ClickCallback

proc newHeader(id: int): TextNode =
  let titleTxt = newText(gResMgr.font("UIFontMedium"), getText(id), thCenter)
  result = newTextNode(titleTxt)
  result.pos = vec2(ScreenWidth/2f - titleTxt.bounds.x/2f, 450f)

proc onButton(src: Node, event: EventKind, pos: Vec2f, tag: pointer) =
  let id = cast[int](tag)
  case event:
  of Enter:
    src.color = Yellow
    playSoundHover()
  of Leave:
    src.color = White
  of Down:
    let dlg = cast[QuitDialog](src.getParent())
    src.color = White
    dlg.clickCbk(dlg, id)
  else:
    discard

proc newButton(id: int, x: float32): TextNode =
  let titleTxt = newText(gResMgr.font("UIFontLarge"), getText(id), thCenter)
  result = newTextNode(titleTxt)
  result.setAnchorNorm(vec2(0.5f, 0.5f))
  result.pos = vec2(ScreenWidth/2f + x, 280f)
  result.addButton(onButton, cast[pointer](id))

proc newBackground(): SpriteNode =
  let sheet = gResMgr.spritesheet("SaveLoadSheet")
  result = newSpriteNode(gResMgr.texture(sheet.meta.image), sheet.frame("error_dialog_small"))
  result.scale = vec2(4f, 4f)
  result.pos = vec2(ScreenWidth/2f, ScreenHeight/2f)

proc newQuitDialog*(clickCbk: ClickCallback): QuitDialog =
  result = QuitDialog(clickCbk: clickCbk)
  result.addChild newBackground()
  result.addChild newHeader(QuitText)
  result.addChild newButton(Yes, -120f)
  result.addChild newButton(No, 120f)

  result.init()

method drawCore(self: QuitDialog, transf: Mat4f) =
  gfxDrawQuad(vec2(0f, 0f), vec2f(ScreenWidth, ScreenHeight), rgbaf(Black, 0.5f), transf)

import glm
import node
import textnode
import spritenode
import ../gfx/text
import ../gfx/spritesheet
import ../game/resmanager
import ../game/screen
import ../io/textdb

const
  PauseText = 99951

type
  PauseDialog* = ref object of Node

proc newLabel(id: int): TextNode =
  let titleTxt = newText(gResMgr.font("sayline"), getText(id), thCenter)
  result = newTextNode(titleTxt)
  result.setAnchorNorm(vec2(0.5f, 0.5f))
  result.pos = vec2(ScreenWidth/2f, ScreenHeight/2f)

proc newBackground(): SpriteNode =
  let sheet = gResMgr.spritesheet("SaveLoadSheet")
  result = newSpriteNode(gResMgr.texture(sheet.meta.image), sheet.frame("pause_dialog"))
  result.scale = vec2(4f, 4f)
  result.pos = vec2(ScreenWidth/2f, ScreenHeight/2f)

proc newPauseDialog*(): PauseDialog =
  result = PauseDialog()
  result.addChild newBackground()
  result.addChild newLabel(PauseText)

  result.init()

import std/strformat
import std/sequtils
import glm
import node
import uinode
import spritenode
import textnode
import ../audio/audio
import ../gfx/color
import ../gfx/text
import ../game/resmanager
import ../game/screen
import ../game/states/state
import ../io/textdb

const
  Back = 99904
  Next = 99962
  Prev = 99963

type 
  HelpDialog* = ref object of UINode
    pages: seq[int]
    page: int

proc updatePage(self: HelpDialog)

proc nextPage(self: HelpDialog) =
  inc self.page
  self.updatePage()

proc prevPage(self: HelpDialog) =
  dec self.page
  self.updatePage()

proc onButton(src: Node, event: EventKind, pos: Vec2f, tag: pointer) =
  let id = cast[int](tag)
  case event:
  of Enter:
    src.color = Yellow
    playSoundHover()
  of Leave:
    src.color = White
  of Down:
    let dlg = cast[HelpDialog](src.getParent())
    src.color = White
    case id:
    of Next:
      dlg.nextPage()
    of Prev:
      dlg.prevPage()
    of Back:
      popState(1)
    else:
      discard
  else:
    discard

proc newButton(id: int, pos: Vec2f): TextNode =
  let titleTxt = newText(gResMgr.font("UIFontLarge"), getText(id), thCenter)
  result = newTextNode(titleTxt)
  result.setAnchorNorm(vec2(0.5f, 0.5f))
  result.pos = pos
  result.addButton(onButton, cast[pointer](id))

proc newBackground*(): SpriteNode =
  result = newSpriteNode(gResMgr.texture("HelpScreen_bg.png"))
  result.pos = vec2(ScreenWidth/2f, -ScreenHeight/2f)

proc updatePage(self: HelpDialog) =
  let name = fmt"HelpScreen_{self.pages[self.page]:02}_en.png"
  let page = newSpriteNode(gResMgr.texture(name))
  page.pos = vec2(ScreenWidth/2f, -ScreenHeight/2f)

  let scale = 0.75f
  let back = newButton(Back, vec2(32f, ScreenHeight - 32f))
  back.scale = vec2(scale, scale)
  back.setAnchorNorm(vec2(0f, 0f))
  let prev = newButton(Prev, vec2(32f, 32f))
  prev.scale = vec2(scale, scale)
  prev.setAnchorNorm(vec2(0f, 1f))
  let next = newButton(Next, vec2(ScreenWidth - 32f, 32f))
  next.scale = vec2(scale, scale)
  next.setAnchorNorm(vec2(1f, 1f))

  self.removeAll()
  self.addChild newBackground()
  self.addChild page
  self.addChild back
  if self.page > 0:
    self.addChild prev
  if self.page < self.pages.len - 1:
    self.addChild next

proc newHelpDialog*(pages: openArray[int]): HelpDialog =
  result = HelpDialog(pages: pages.toSeq)
  result.init()
  result.updatePage()
  
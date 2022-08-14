import glm
import node
import textnode
import spritenode
import ../gfx/color
import ../gfx/text
import ../gfx/spritesheet
import ../game/resmanager
import ../game/screen
import ../io/textdb

const
  Options = 99913
  SaveGame = 99911
  LoadGame = 99910
  Sound = 99916
  Video = 99917
  Controls = 99918
  TextAndSpeech = 99919
  Help = 99961
  Quit = 99915
  Back = 99904

type
  OptionsDialog* = ref object of Node

var
  gDisabled: seq[int]

proc onButtonDown(node: Node, id: int) =
  case id:
  of Quit:
    quit()
  else:
    discard

proc onButton(src: Node, event: EventKind, pos: Vec2f, tag: pointer) =
  let id = cast[int](tag)
  case event:
  of Enter:
    if not gDisabled.contains(id):
      src.color = Yellow
  of Leave:
    src.color = White
  of Down:
    onButtonDown(src.getParent, id)
  else:
    discard

proc newLabel(id: int, y: float, font = "UIFontLarge"): TextNode =
  let titleTxt = newText(gResMgr.font(font), getText(id), thCenter)
  result = newTextNode(titleTxt)
  result.pos = vec2(ScreenWidth/2f - titleTxt.bounds.x/2f, y)
  result.alpha = if gDisabled.contains(id): 0.5f else: 1f
  result.addButton(onButton, cast[pointer](id))

proc newBackground(): SpriteNode =
  let sheet = gResMgr.spritesheet("SaveLoadSheet")
  result = newSpriteNode(gResMgr.texture(sheet.meta.image), sheet.frame("options_background"))
  result.scale = vec2(4f, 4f)
  result.pos = vec2(ScreenWidth/2f, ScreenHeight/2f)

proc newOptionsDialog*(): OptionsDialog =
  result = OptionsDialog()
  result.init()

  gDisabled.add SaveGame
  
  result.addChild newBackground()
  result.addChild newLabel(Options, 680f, "HeadingFont")
  result.addChild newLabel(SaveGame, 600f)
  result.addChild newLabel(LoadGame, 540f)
  result.addChild newLabel(Sound, 480f)
  result.addChild newLabel(Video, 420f)
  result.addChild newLabel(Controls, 360f)
  result.addChild newLabel(TextAndSpeech, 300f)
  result.addChild newLabel(Help, 240f)
  result.addChild newLabel(Quit, 180f)
  result.addChild newLabel(Back, 100f, "UIFontMedium")

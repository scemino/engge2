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
  SliderCallback* = proc(self: Slider, value: float32)
  Slider* = ref object of Node
    id*: int
    tag*: pointer
    value, min, max: float32
    callback: SliderCallback

proc onButton(src: Node, event: EventKind, pos: Vec2f, tag: pointer) =
  let slider = cast[Slider](tag)
  case event:
  of Enter:
    src.color = Yellow
  of Leave:
    src.color = White
  of Drag:
    let x = clamp(pos.x, slider.min, slider.max)
    let value = (x - slider.min) / (slider.max - slider.min)
    src.pos = vec2(x, src.pos.y)
    slider.callback(slider, value)
  else:
    discard

proc newSlider*(id: int, y: float, callback: SliderCallback, value: float, tag: pointer = nil): Slider =
  result = Slider(id: id, callback: callback, value: value, tag: tag)
  result.init()

  let titleTxt = newText(gResMgr.font("UIFontSmall"), getText(id), thLeft)
  let tn = newTextNode(titleTxt)
  tn.setAnchorNorm(vec2(0f, 0.5f))
  tn.pos = vec2f(420f, 0f)
  result.addChild tn

  let sheet = gResMgr.spritesheet("SaveLoadSheet")
  let slider = newSpriteNode(gResMgr.texture(sheet.meta.image), sheet.frame("slider"))
  slider.scale = vec2(4f, 4f)
  slider.pos = vec2(ScreenWidth/2f, -titleTxt.bounds.y)
  result.addChild slider

  result.min = ScreenWidth/2f-4f*slider.size.x/2f
  result.max = ScreenWidth/2f+4f*slider.size.x/2f

  let handle = newSpriteNode(gResMgr.texture(sheet.meta.image), sheet.frame("slider_handle"))
  handle.scale = vec2(4f, 4f)
  handle.pos = vec2(result.min, -titleTxt.bounds.y)
  handle.addButton(onButton, cast[pointer](result))
  result.addChild handle

  result.pos.y = y

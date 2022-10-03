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
    slider, handle: SpriteNode
    text: TextNode

proc handlePos(self: Slider, value: float): float32 =
  self.min + value * (self.max - self.min)

proc onButton(src: Node, event: EventKind, pos: Vec2f, tag: pointer = nil) =
  let slider = cast[Slider](tag)
  case event:
  of Enter:
    slider.text.color = Yellow
    slider.slider.color = Yellow
  of Leave:
    slider.text.color = White
    slider.slider.color = White
  of Drag:
    let x = clamp(pos.x, slider.min, slider.max)
    let value = (x - slider.min) / (slider.max - slider.min)
    slider.handle.pos = vec2(x, src.pos.y)
    slider.callback(slider, value)
  else:
    discard

proc newSlider*(id: int, y: float, callback: SliderCallback, value: float, tag: pointer = nil): Slider =
  result = Slider(id: id, callback: callback, value: value, tag: tag)
  result.init()

  let titleTxt = newText(gResMgr.font("UIFontSmall"), getText(id), thCenter)
  let tn = newTextNode(titleTxt)
  tn.setAnchorNorm(vec2(0.5f, 0.5f))
  tn.pos = vec2f(ScreenWidth/2f, 0f)
  result.addChild tn

  let sheet = gResMgr.spritesheet("SaveLoadSheet")
  let slider = newSpriteNode(gResMgr.texture(sheet.meta.image), sheet.frame("slider"))
  slider.scale = vec2(4f, 4f)
  slider.pos = vec2(ScreenWidth/2f, -titleTxt.bounds.y)
  slider.addButton(onButton, cast[pointer](result))
  result.addChild slider

  result.min = ScreenWidth/2f-4f*slider.size.x/2f
  result.max = ScreenWidth/2f+4f*slider.size.x/2f

  let handle = newSpriteNode(gResMgr.texture(sheet.meta.image), sheet.frame("slider_handle"))
  handle.scale = vec2(4f, 4f)
  handle.pos = vec2(result.handlePos(value), -titleTxt.bounds.y)
  handle.addButton(onButton, cast[pointer](result))
  result.addChild handle

  result.text = tn
  result.slider = slider
  result.handle = handle
  result.pos.y = y

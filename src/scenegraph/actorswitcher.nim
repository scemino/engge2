import glm
import node
import ../gfx/graphics
import ../gfx/spritesheet
import ../gfx/color
import ../gfx/recti
import ../gfx/texture
import ../game/resmanager
import ../game/screen
import ../sys/app

const
  DisableAlpha = 0.5f
  EnableAlpha = 1f
  Margin = 30f
  ActorSep = 60f
  AnimDuration = 0.120f

type
  ActorSlotSelectableMode* = enum
    asOn = 1
    asTemporaryUnselectable = 2
  ActorSwitcherSlot* = object
    ## This is where all the information about the actor icon stands
    icon*: string
    back*, frame*: Color
    selectFunc*: proc()
  ActorSwitcher* = ref object of Node
    ## This allows to change the selected actors or to display the options (gear icon)
    mouseOver: bool                       ## true when mouse is over the icons
    down: bool                            ## true when mouse button is down
    alpha: float32                        ## alpha value for the icon when flash is ON (flash != 0)
    flash*: int                           ## flash = 0: disable, flash = -1: enable, other values: time to flash
    flashElapsed: float32                 ## flash time elapsed in seconds
    animElapsed, animPos: float32         ## animation time elapsed in seconds and current position in the animation [0f-1f]
    mode*: set[ActorSlotSelectableMode]   ## current mode
    slots: seq[ActorSwitcherSlot]         ## list of slots containing icon, colors and select function

proc newActorSwitcher*(): ActorSwitcher =
  result = ActorSwitcher(alpha: 1f)
  result.init()

proc drawSprite(sf: SpriteSheetFrame, texture: Texture, color: Color, transf: Mat4f) =
  let pos = vec3f(sf.spriteSourceSize.x.float32 - sf.sourceSize.x.float32 / 2f,  - sf.spriteSourceSize.h.float32 - sf.spriteSourceSize.y.float32 + sf.sourceSize.y.float32 / 2f, 0f)
  let trsf = translate(transf, pos)
  gfxDrawSprite(sf.frame / texture.size, texture, color, trsf)

proc transform(self: ActorSwitcher, transf: Mat4f, index: int): Mat4f =
  let animPos = if self.mouseover: self.animPos else: 1f
  let pos = vec3f(ScreenWidth - Margin, ScreenHeight - Margin - animPos * ActorSep * index.float32, 0f)
  let scale = vec3f(2f, 2f, 0f)
  scale(translate(transf, pos), scale)

proc getAlpha(self: ActorSwitcher, index: int): float32 =
  if asTemporaryUnselectable in self.mode and (index != self.slots.len - 1):
    result = DisableAlpha
  else:
    if asOn in self.mode:
      result = if self.mouseOver: EnableAlpha else: self.alpha
    else:
      result = DisableAlpha

proc drawIcon(self: ActorSwitcher, icon: string, backColor, frameColor: Color, transf: Mat4f, index: int) =
  let gameSheet = gResMgr.spritesheet("GameSheet")
  let texture = gResMgr.texture(gameSheet.meta.image)
  let iconBackFrame = gameSheet.frame("icon_background")
  let iconActorFrame = gameSheet.frame(icon)
  let iconFrame = gameSheet.frame("icon_frame")
  let t = self.transform(transf, index)
  let alpha = self.getAlpha(index)

  drawSprite(iconBackFrame, texture, rgbaf(backColor, alpha), t)
  drawSprite(iconActorFrame, texture, rgbaf(White, alpha), t)
  drawSprite(iconFrame, texture, rgbaf(frameColor, alpha), t)

proc winToScreen*(pos: Vec2f): Vec2f =
  result = (pos / vec2f(appGetWindowSize())) * vec2(ScreenWidth, ScreenHeight)
  result = vec2(result.x, ScreenHeight - result.y)

proc height(self: ActorSwitcher): float32 =
  let n = if self.mouseover: self.slots.len else: 1
  n.float32 * ActorSep

proc rect(self: ActorSwitcher): Rectf =
  let height = self.height
  rectFromPositionSize(vec2(ScreenWidth - ActorSep, ScreenHeight - height), vec2(ActorSep, height))

proc iconIndex*(self: ActorSwitcher, pos: Vec2f): int =
  let y = ScreenHeight - pos.y
  self.slots.len - 1 - ((self.height - y) / ActorSep).int

proc update*(self: ActorSwitcher, slots: seq[ActorSwitcherSlot], elapsed: float) =
  self.slots = slots

  # update flash icon
  if self.flash != 0 and (self.flash == -1 or self.flashElapsed < self.flash.float32):
    self.flashElapsed = self.flashElapsed + elapsed
    self.alpha = 0.6f + 0.4f * sin(PI * 2f * self.flashElapsed)
  else:
    self.flash = 0
    self.flashElapsed = 0f
    self.alpha = DisableAlpha

  # check if mouse is over actor icons or gear icon
  let scrPos = winToScreen(mousePos())
  let oldMouseOver = self.mouseover
  self.mouseover = not self.down and self.rect().contains(scrPos)

  # update anim
  self.animElapsed = self.animElapsed + elapsed

  # stop anim or flash if necessary
  if oldMouseOver != self.mouseover:
    self.animElapsed = 0f
    if self.mouseover:
      self.flash = 0
  
  # update anim pos
  self.animPos = min(1f, self.animElapsed / AnimDuration)

  # check if we select an actor or gear icon
  if self.mouseover and mbLeft in mouseBtns() and not self.down:
    self.down = true
    # check if we allow to select an actor
    let iconIndex = self.iconIndex(scrPos)
    if asTemporaryUnselectable notin self.mode or iconIndex == (self.slots.len - 1):
      let selectFunc = self.slots[iconIndex].selectFunc
      if not selectFunc.isNil:
        selectFunc()
  if mbLeft notin mouseBtns():
    self.down = false

method drawCore(self: ActorSwitcher, transf: Mat4f) =
  if self.mouseOver:
    for i in 0..<self.slots.len:
      let slot = self.slots[i]
      self.drawIcon(slot.icon, slot.back, slot.frame, transf, i)
  elif self.slots.len > 0:
    let slot = self.slots[0]
    self.drawIcon(slot.icon, slot.back, slot.frame, transf, 0)

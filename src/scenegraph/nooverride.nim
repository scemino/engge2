import std/strformat
import glm
import node
import spritenode
import ../gfx/spritesheet
import ../game/resmanager
import ../game/screen

type
  NoOverride* = ref object of Node
    elapsed: float

proc newIcon(): SpriteNode =
  let sheet = gResMgr.spritesheet("GameSheet")
  result = newSpriteNode(gResMgr.texture(sheet.meta.image), sheet.frame("icon_no"))
  result.scale = vec2(2f, 2f)
  result.pos = vec2(32f, ScreenHeight - 32f)

proc newNoOverride*(): NoOverride =
  result = NoOverride()
  result.zOrder = -1000
  result.addChild newIcon()
  result.init()

proc reset*(self: NoOverride) =
  self.elapsed = 0

proc update*(self: NoOverride, elapsed: float): bool =
  if self.elapsed > 2f:
    result =  false
  else:
    self.elapsed += elapsed
    self.alpha = clamp((2f - self.elapsed) / 2f, 0f, 1f)
    echo fmt"no override: {self.elapsed}, {self.alpha}"
    result =  true

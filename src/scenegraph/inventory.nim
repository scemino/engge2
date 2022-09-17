import std/tables
import glm
import node
import ../gfx/graphics
import ../gfx/spritesheet
import ../gfx/color
import ../gfx/recti
import ../gfx/texture
import ../game/resmanager
import ../game/screen
import ../game/room
import ../game/prefs
import ../sys/app

const
  NumObjects = 8
  NumObjectsByRow = 4
  Margin = 8f
  MarginBottom = 10f
  BackOffset = 7f
  ArrowWidth = 56f
  ArrowHeight = 86f
  BackWidth = 137f
  BackHeight = 75f

type
  Inventory* = ref object of Node
    actor: Object
    backColor, verbNormal: Color
    down: bool
    obj*: Object

var
  gArrowUpRect = rect(ScreenWidth / 2f, ArrowHeight + MarginBottom + BackOffset, ArrowWidth, ArrowHeight)
  gArrowDnRect = rect(ScreenWidth / 2f, MarginBottom, ArrowWidth, ArrowHeight)
  gItemRects: array[NumObjects, Rectf]

proc newInventory*(): Inventory =
  result = Inventory()
  result.init()
  for i in 0..<gItemRects.len:
    let x = ScreenWidth / 2f + ArrowWidth + Margin + ((i mod NumObjectsByRow).float32*(BackWidth + BackOffset))
    let y = MarginBottom + BackHeight + BackOffset - ((i div NumObjectsByRow).float32 * (BackHeight + BackOffset))
    gItemRects[i] = rect(x, y, BackWidth, BackHeight)

proc drawSprite(sf: SpriteSheetFrame, texture: Texture, color: Color, transf: Mat4f) =
  let pos = vec3f(sf.spriteSourceSize.x.float32 - sf.sourceSize.x.float32 / 2f,  - sf.spriteSourceSize.h.float32 - sf.spriteSourceSize.y.float32 + sf.sourceSize.y.float32 / 2f, 0f)
  let trsf = translate(transf, pos)
  gfxDrawSprite(sf.frame / texture.size, texture, color, trsf)

proc drawBack(self: Inventory, transf: Mat4f) =
  let gameSheet = gResMgr.spritesheet("GameSheet")
  let texture = gResMgr.texture(gameSheet.meta.image)
  let back = gameSheet.frame("inventory_background")

  let startOffsetX = ScreenWidth / 2f + ArrowWidth + Margin + back.sourceSize.x.float32 / 2f
  var offsetX = startOffsetX
  var offsetY = 3f * back.sourceSize.y.float32/2f + MarginBottom + BackOffset

  for i in 0..<4:
    let t = translate(transf, vec3(offsetX, offsetY, 0f))
    drawSprite(back, texture, self.backColor, t)
    offsetX += back.sourceSize.x.float32 + BackOffset

  offsetX = startOffsetX
  offsetY = back.sourceSize.y.float32/2f + MarginBottom
  for i in 0..<4:
    let t = translate(transf, vec3(offsetX, offsetY, 0f))
    drawSprite(back, texture, self.backColor, t)
    offsetX += back.sourceSize.x.float32 + BackOffset

proc hasUpArrow(actor: Object): bool =
  actor.inventoryOffset != 0

proc hasDownArrow(actor: Object): bool =
  actor.inventory.len > (actor.inventoryOffset * NumObjectsByRow + NumObjects)

proc drawArrows(self: Inventory, transf: Mat4f) =
  let isRetro = prefs(RetroVerbs)
  let gameSheet = gResMgr.spritesheet("GameSheet")
  let texture = gResMgr.texture(gameSheet.meta.image)
  let arrowUp = gameSheet.frame(if isRetro: "scroll_up_retro" else: "scroll_up")
  let arrowDn = gameSheet.frame(if isRetro: "scroll_down_retro" else: "scroll_down")
  let alphaUp = if self.actor.hasUpArrow(): 1f else: 0f
  let alphaDn = if self.actor.hasDownArrow(): 1f else: 0f
  let tUp = translate(transf, vec3(ScreenWidth/2f + ArrowWidth / 2f + Margin, 1.5f * ArrowHeight + BackOffset, 0f))
  let tDn = translate(transf, vec3(ScreenWidth/2f + ArrowWidth / 2f + Margin, 0.5f * ArrowHeight, 0f))

  drawSprite(arrowUp, texture, rgbaf(self.verbNormal, alphaUp), tUp)
  drawSprite(arrowDn, texture, rgbaf(self.verbNormal, alphaDn), tDn)

proc getScale(self: Object): float32 =
  if self.getPop() > 0:
    result = 4.25f + self.popScale() * 0.25f
  else:
    result = 4f

proc drawItems(self: Inventory, transf: Mat4f) =
  let startOffsetX = ScreenWidth / 2f + ArrowWidth + Margin + BackWidth / 2f
  let startOffsetY = MarginBottom + 1.5f * BackHeight + BackOffset
  let itemsSheet = gResMgr.spritesheet("InventoryItems")
  let texture = gResMgr.texture(itemsSheet.meta.image)
  let count = min(NumObjects, self.actor.inventory.len - self.actor.inventoryOffset * NumObjectsByRow)
  
  for i in 0..<count:
    let obj = self.actor.inventory[self.actor.inventoryOffset * NumObjectsByRow + i]
    let icon = obj.getIcon()
    if itemsSheet.frameTable.hasKey(icon):
      let itemFrame = itemsSheet.frame(icon)
      let pos = vec2(startOffsetX + ((i mod NumObjectsByRow).float32*(BackWidth + BackOffset)), startOffsetY - ((i div NumObjectsByRow).float32 * (BackHeight + BackOffset)))
      let scale = obj.getScale()
      let t = scale(translate(transf, vec3(pos, 0f)), vec3(scale, scale, 0f))
      drawSprite(itemFrame, texture, White, t)

proc winToScreen(pos: Vec2f): Vec2f =
  result = (pos / vec2f(appGetWindowSize())) * vec2(ScreenWidth, ScreenHeight)
  result = vec2(result.x, ScreenHeight - result.y)

proc getPos*(self: Inventory, inv: Object): Vec2f =
  if not self.actor.isNil:
    let i = self.actor.inventory.find(inv) - self.actor.inventoryOffset * NumObjectsByRow
    return gItemRects[i].pos + gItemRects[i].size / 2f

proc update*(self: Inventory, elapsed: float32, actor: Object = nil, backColor = Black, verbNormal = Black) =
  # udate colors
  self.actor = actor
  self.backColor = backColor
  self.verbNormal = verbNormal

  self.obj = nil
  if not self.actor.isNil:
    let scrPos = winToScreen(mousePos())

    # update mouse click
    let down = mbLeft in mouseBtns()
    if not self.down and down:
      self.down = true
      if gArrowUpRect.contains(scrPos):
        self.actor.inventoryOffset -= 1
        if self.actor.inventoryOffset < 0:
          self.actor.inventoryOffset = clamp(self.actor.inventoryOffset, 0, (self.actor.inventory.len - 5) div 4)
      elif gArrowDnRect.contains(scrPos):
        self.actor.inventoryOffset += 1
        self.actor.inventoryOffset = clamp(self.actor.inventoryOffset, 0, (self.actor.inventory.len - 5) div 4)
    elif not down:
      self.down = false

    for i in 0..<gItemRects.len:
      let item = gItemRects[i]
      if item.contains(scrPos):
        let index = self.actor.inventoryOffset * NumObjectsByRow + i
        if index < self.actor.inventory.len:
          self.obj = self.actor.inventory[index]
        break

    for obj in self.actor.inventory:
      obj.update(elapsed)

method drawCore(self: Inventory, transf: Mat4f) =
  if not self.actor.isNil:
    self.drawArrows(transf)
    self.drawBack(transf)
    self.drawItems(transf)

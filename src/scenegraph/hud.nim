import std/logging
import std/strformat
import std/tables
import glm
import node
import spritenode
import ../game/resmanager
import ../gfx/color
import ../gfx/recti
import ../gfx/spritesheet
import ../game/room
import ../game/verb
import ../game/screen
import ../game/motors/shake
import ../script/squtils

type
  ActorSlotSelectableMode* = enum
    asOn = 1
    asTemporaryUnselectable = 2
  Verb* = object
    id*: VerbId
    image*: string
    fun*: string
    text*: string 
    key*: string
    flags*: int
  VerbUiColors* = object
    sentence*: Color
    verbNormal*: Color
    verbNormalTint*: Color
    verbHighlight*: Color
    verbHighlightTint*: Color
    dialogNormal*: Color
    dialogHighlight*: Color
    inventoryFrame*: Color
    inventoryBackground*: Color
    retroNormal*: Color
    retroHighlight*: Color
  ActorSlot* = ref object of RootObj
    verbUiColors*: VerbUiColors
    verbs*: array[22, Verb]
    selectable*: bool
    actor*: Object
  Hud* = ref object of Node
    actorSlots*: array[6, ActorSlot]
    mode*: set[ActorSlotSelectableMode]
    backingItems, inventory: Node
    scrollUp, scrollDn: SpriteNode
    verbNodes*: array[9, SpriteNode]
    inventoryNodes: array[8, SpriteNode]
    act*: Object
    slot*: ActorSlot
    verbRects: array[9, VerbRect]
    invRects: array[8, InventoryRect]
    scrollRects: array[2, ScrollRect]
    verb*: Verb
    obj*: Object
  VerbRect = object
    hud*: Hud
    index*: int
  InventoryRect = object
    hud*: Hud
    index*: int
  ScrollRect = object
    hud*: Hud
    offset*: int

proc onVerb(src: Node, event: EventKind, pos: Vec2f, tag: pointer)
proc onInventoryObject(src: Node, event: EventKind, pos: Vec2f, tag: pointer)
proc onScroll(src: Node, event: EventKind, pos: Vec2f, tag: pointer)

proc newHud*(): Hud =
  var hud = Hud()
  result = hud
  for i in 0..<result.actorSlots.len:
    result.actorSlots[i] = ActorSlot()
  result.init()

  # UI backing
  let gameSheet = gResMgr.spritesheet("GameSheet")
  let frame = gameSheet.frame("ui_backing")
  let texture = gResMgr.texture(gameSheet.meta.image)
  let backing = newSpriteNode(texture, frame)
  backing.name = "uiBacking"
  backing.setAnchorNorm(vec2(0f, 0f))
  backing.nodeColor = rgbaf(Black, 0.33f)
  result.addChild backing

  let backingItems = Node()
  backingItems.init()
  result.backingItems = backingItems
  backing.addChild backingItems

  # draw verbs
  let verbSheet = gResMgr.spritesheet("VerbSheet")
  let verbTexture = gResMgr.texture(verbSheet.meta.image)
  let verbFrame = verbSheet.frame("lookat_en")
  for i in 0..<9:
    result.verbRects[i] = VerbRect(hud: result, index: i)
    result.verbNodes[i] = newSpriteNode(verbTexture, verbFrame)
    result.verbNodes[i].setAnchorNorm(vec2f(0f, 0f))
    result.verbNodes[i].pos = vec2(verbFrame.spriteSourceSize.x.float32, verbFrame.sourceSize.y.float32 - verbFrame.spriteSourceSize.y.float32 - verbFrame.spriteSourceSize.h.float32)
    result.verbNodes[i].addButton(onVerb, result.verbRects[i].addr)
    backingItems.addChild result.verbNodes[i]

  # draw scroll up
  let scUpFrame = gameSheet.frame("scroll_up")
  let scrollUp = newSpriteNode(texture, scUpFrame)
  scrollUp.name = "scroll_up"
  scrollUp.pos = vec2(ScreenWidth/2f, scUpFrame.sourceSize.y.float32)
  scrollUp.setAnchorNorm(vec2f(0f, 0f))
  result.scrollRects[0] = ScrollRect(hud: hud, offset: -1)
  scrollUp.addButton(onScroll, result.scrollRects[0].addr)
  result.scrollUp = scrollUp
  backingItems.addChild scrollUp

  # draw scroll down
  let scDnFrame = gameSheet.frame("scroll_down")
  let scrollDn = newSpriteNode(texture, scDnFrame)
  scrollDn.name = "scroll_down"
  scrollDn.pos = vec2(ScreenWidth/2f, 0'f32)
  scrollDn.setAnchorNorm(vec2f(0f, 0f))
  result.scrollRects[1] = ScrollRect(hud: hud, offset: 1)
  scrollDn.addButton(onScroll, result.scrollRects[1].addr)
  result.scrollDn = scrollDn
  backingItems.addChild scrollDn

  # draw inventory background
  let inventory = Node()
  inventory.name = "inventory"
  inventory.init()
  result.inventory = inventory
  backing.addChild inventory

  let startOffsetX = ScreenWidth/2f + scDnFrame.sourceSize.x.float32 + 4f
  var offsetX = startOffsetX
  let inventoryFrame = gameSheet.frame("inventory_background")
  
  # draw first inventory row
  for i in 1..4:
    let node = newSpriteNode(texture, inventoryFrame)
    node.pos = vec2f(offsetX, 8f)
    node.setAnchorNorm(vec2(0f, 1f))
    inventory.addChild node
    offsetX += inventoryFrame.sourceSize.x.float32 + 4f
  offsetX = startOffsetX
  
  # draw second inventory row
  for i in 1..4:
    let node = newSpriteNode(texture, inventoryFrame)
    node.pos = vec2f(offsetX, 4f)
    node.setAnchorNorm(vec2(0f, 0f))
    inventory.addChild node
    offsetX += inventoryFrame.sourceSize.x.float32 + 4f
    
  # draw inventory objects
  offsetX = startOffsetX + scDnFrame.sourceSize.x.float32 / 2f
  let itemsSheet = gResMgr.spritesheet("InventoryItems")
  let inventoryItemsTexture = gResMgr.texture(itemsSheet.meta.image)
  let inventoryItemsFrame = itemsSheet.frame("background")
  for i in 0..7:
    var node = newSpriteNode(inventoryItemsTexture, inventoryItemsFrame)
    node.pos = vec2f(offsetX, 0f)
    node.setAnchorNorm(vec2(0.5f, 1f))
    node.scale = vec2(4f, 4f)
    result.inventoryNodes[i] = node
    backing.addChild node
    offsetX += frame.sourceSize.x.float32 + 4f

proc actorSlot*(self: Hud, actor: Object): ActorSlot =
  for slot in self.actorSlots.mitems:
    if slot.actor == actor:
      return slot

proc verb*(self: ActorSlot, verbId: VerbId): Verb =
  for verb in self.verbs:
    if verb.id == verbId:
      return verb

proc hasUpArrow(actor: Object): bool =
  actor.inventoryOffset != 0;

proc hasDownArrow(actor: Object): bool =
  actor.inventory.len > (actor.inventoryOffset * 4 + 8)

proc updateInventory*(self: Hud) =
  if not self.act.isNil:
    let startOffsetX = 640f + 56f + 137f / 2f
    let startOffsetY = 4f + 75f
    let itemsSheet = gResMgr.spritesheet("InventoryItems")
    let count = self.act.inventory.len - self.act.inventoryOffset * 4
    for i in 0..<min(8, count):
      let obj = self.act.inventory[self.act.inventoryOffset * 4 + i]
      let icon = obj.getIcon()
      if itemsSheet.frameTable.hasKey(icon):
        let itemFrame = itemsSheet.frame(icon)
        self.invRects[i] = InventoryRect(hud: self, index: self.act.inventoryOffset * 4 + i)
        self.inventoryNodes[i].color = White
        self.inventoryNodes[i].pos = vec2(startOffsetX + ((i mod 4)*(137+7)).float32, startOffsetY - ((i div 4)*75).float32)
        self.inventoryNodes[i].setFrame(itemFrame)
        self.inventoryNodes[i].scale = vec2(4f, 4f)
        self.inventoryNodes[i].setAnchorNorm(vec2f(0.5f, 0f))
        self.inventoryNodes[i].addButton(onInventoryObject, self.invRects[i].addr)
      else:
        warn fmt"Icon '{icon}' for object {obj.name}({obj.key}) not found in InventoryItems spritesheet"

proc getPos*(self: Hud, inv: Object): Vec2f =
  if not self.act.isNil:
    let itemsSheet = gResMgr.spritesheet("InventoryItems")
    let count = self.act.inventory.len - self.act.inventoryOffset * 4
    for i in 0..<min(8, count):
      let obj = self.act.inventory[self.act.inventoryOffset * 4 + i]
      if obj.table.getId() == inv.table.getId():
        let icon = obj.getIcon()
        if itemsSheet.frameTable.hasKey(icon):
          return self.inventoryNodes[i].pos + self.inventoryNodes[i].size/2f

proc `actor=`*(self: Hud, actor: Object) =
  let actorSlot = self.actorSlot(actor)
  self.backingItems.color = actorSlot.verbUiColors.verbNormal
  self.inventory.color = actorSlot.verbUiColors.inventoryBackground

  # updates verbs
  let verbSheet = gResMgr.spritesheet("VerbSheet")
  for i in 1..<actorSlot.verbs.len:
    let verb = actorSlot.verbs[i]
    if verb.image.len > 0:
      let verbFrame = verbSheet.frame(fmt"{verb.image}_en")
      self.verbNodes[i-1].pos = vec2(verbFrame.spriteSourceSize.x.float32, verbFrame.sourceSize.y.float32 - verbFrame.spriteSourceSize.y.float32 - verbFrame.spriteSourceSize.h.float32)
      self.verbNodes[i-1].setFrame(verbFrame)
      self.verbNodes[i-1].setAnchorNorm(vec2f(0f, 0f))

  # update scroll arrows
  self.scrollDn.alpha = if actor.hasDownArrow(): 1f else: 0f
  self.scrollUp.alpha = if actor.hasUpArrow(): 1f else: 0f

  info fmt"Update actor to {actor.name}"
  self.slot = self.actorSlot(actor)
  self.verb = self.slot.verbs[0]
  self.act = actor

  self.updateInventory()

proc onVerb(src: Node, event: EventKind, pos: Vec2f, tag: pointer) =
  let verbRect = cast[ptr VerbRect](tag)
  case event:
  of Enter:
    src.color = verbRect.hud.slot.verbUiColors.verbHighlight
    src.shakeMotor = newShake(0.3, src, 1.2f)
  of Leave:
    src.color = verbRect.hud.slot.verbUiColors.verbNormal
  of Down:
    verbRect.hud.verb = verbRect.hud.slot.verbs[verbRect.index + 1]
    info fmt"verb {verbRect.hud.verb.fun} selected"
  else:
    discard

proc onInventoryObject(src: Node, event: EventKind, pos: Vec2f, tag: pointer) =
  let invRect = cast[ptr InventoryRect](tag)
  let obj = invRect.hud.act.inventory[invRect.index]
  let name = if obj.isNil: "(none)" else: obj.name
  info fmt"on inventory object {name}"
  case event:
  of Enter:
    src.shakeMotor = newShake(0.3, src, 1.2f)
    invRect.hud.obj = invRect.hud.act.inventory[invRect.index]
  of Leave:
    invRect.hud.obj = nil
  of Down:
    discard
  else:
    discard

proc onScroll(src: Node, event: EventKind, pos: Vec2f, tag: pointer) =
  let rect = cast[ptr ScrollRect](tag)
  case event:
  of Down:
    rect.hud.act.inventoryOffset += rect.offset
    rect.hud.act.inventoryOffset = min(rect.hud.act.inventoryOffset, 0)
    info fmt"onScroll {rect.hud.act.inventoryOffset} {rect.offset}"
    rect.hud.updateInventory()
  else:
    discard

import std/logging
import std/strformat
import glm
import node
import spritenode
import sqnim
import ../game/resmanager
import ../gfx/color
import ../gfx/recti
import ../gfx/spritesheet
import ../game/room
import ../game/verb
import ../game/prefs
import ../game/motors/shake
import ../script/squtils
import ../script/vm

const
  NumVerbs = 9
  NumActors = 6

type
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
    actorSlots*: array[NumActors, ActorSlot]
    backingItems: Node
    scrollUp, scrollDn: SpriteNode
    verbNodes*: array[NumVerbs, SpriteNode]
    act*: Object
    slot*: ActorSlot
    verbRects: array[NumVerbs, VerbRect]
    verb*: Verb
  VerbRect = object
    hud*: Hud
    index*: int

proc onVerb(src: Node, event: EventKind, pos: Vec2f, tag: pointer)

proc newHud*(): Hud =
  var hud = Hud()
  result = hud
  for i in 0..<result.actorSlots.len:
    result.actorSlots[i] = ActorSlot()
  result.init()
  result.zOrder = 100

  # UI backing
  let gameSheet = gResMgr.spritesheet("GameSheet")
  let frame = gameSheet.frame("ui_backing")
  let texture = gResMgr.texture(gameSheet.meta.image)
  let backing = newSpriteNode(texture, frame)
  backing.name = "uiBacking"
  backing.setAnchorNorm(vec2(0f, 0f))
  backing.color = Black
  backing.alpha = 0.33f
  result.addChild backing

  let backingItems = Node()
  backingItems.init()
  result.backingItems = backingItems
  result.addChild backingItems

  # draw verbs
  let verbSheet = gResMgr.spritesheet("VerbSheet")
  let verbTexture = gResMgr.texture(verbSheet.meta.image)
  let verbFrame = verbSheet.frame("lookat_en")
  for i in 0..<NumVerbs:
    result.verbRects[i] = VerbRect(hud: result, index: i)
    result.verbNodes[i] = newSpriteNode(verbTexture, verbFrame)
    result.verbNodes[i].setAnchorNorm(vec2f(0f, 0f))
    result.verbNodes[i].pos = vec2(verbFrame.spriteSourceSize.x.float32, verbFrame.sourceSize.y.float32 - verbFrame.spriteSourceSize.y.float32 - verbFrame.spriteSourceSize.h.float32)
    result.verbNodes[i].addButton(onVerb, result.verbRects[i].addr)
    backingItems.addChild result.verbNodes[i]

proc actorSlot*(self: Hud, actor: Object): ActorSlot =
  for slot in self.actorSlots.mitems:
    if slot.actor == actor:
      return slot

proc verb*(self: ActorSlot, verbId: VerbId): Verb =
  for verb in self.verbs:
    if verb.id == verbId:
      return verb

proc `actor=`*(self: Hud, actor: Object) =
  let actorSlot = self.actorSlot(actor)
  self.backingItems.color = actorSlot.verbUiColors.verbNormal

  # updates verbs
  let verbSheet = gResMgr.spritesheet("VerbSheet")
  let lang = prefs(Lang)
  let isRetroVerbs = prefs(RetroVerbs)
  let verbSuffix = if isRetroVerbs: "_retro" else: ""
  for i in 1..<actorSlot.verbs.len:
    let verb = actorSlot.verbs[i]
    if verb.image.len > 0:
      let verbFrame = verbSheet.frame(fmt"{verb.image}{verbSuffix}_{lang}")
      self.verbNodes[i-1].pos = vec2(verbFrame.spriteSourceSize.x.float32, verbFrame.sourceSize.y.float32 - verbFrame.spriteSourceSize.y.float32 - verbFrame.spriteSourceSize.h.float32)
      self.verbNodes[i-1].setFrame(verbFrame)
      self.verbNodes[i-1].setAnchorNorm(vec2f(0f, 0f))
      self.verbNodes[i-1].color = actorSlot.verbUiColors.verbNormal

  info fmt"Update actor to {actor.name}"
  self.slot = self.actorSlot(actor)
  self.verb = self.slot.verbs[0]
  self.act = actor
  
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
    sqCall("onVerbClick")
  else:
    discard

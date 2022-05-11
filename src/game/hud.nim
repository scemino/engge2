import ../gfx/color
import room
import verb

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
  Hud* = ref object of RootObj
    actorSlots*: array[6, ActorSlot]
    mode*: set[ActorSlotSelectableMode]

proc newHud*(): Hud =
  new(result)
  for i in 0..<result.actorSlots.len:
    result.actorSlots[i] = ActorSlot()

proc actorSlot*(self: Hud, actor: Object): ActorSlot =
  for slot in self.actorSlots.mitems:
    if slot.actor == actor:
      return slot

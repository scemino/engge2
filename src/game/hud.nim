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
  ActorSlot* = object
    verbUiColors*: VerbUiColors
    verbs*: array[10, Verb]
    selectable*: bool
    actor*: Object
  Hud* = object
    actorSlots*: array[6, ActorSlot]
    mode*: set[ActorSlotSelectableMode]
  
proc actorSlot*(self: var Hud, actor: Object): var ActorSlot =
  for slot in self.actorSlots.mitems:
    if slot.actor == actor:
      return slot

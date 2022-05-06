import ../gfx/color
import room
import verb

type
  Verb* = object
    id*: VerbId
    image*: string
    fun*: string
    text*: string 
    key*: string
    flags*: int
  ActorSlot* = object
    verbs*: array[10, Verb]
    selectable*: bool
    actor*: Object
  Hud* = object
    actorSlots*: array[6, ActorSlot]
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
  
proc actorSlot*(self: Hud, actor: Object): ActorSlot =
  for slot in self.actorSlots:
    if slot.actor == actor:
      return slot

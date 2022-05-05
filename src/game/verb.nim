const
  FAR_LOOK* = 8
type
  VerbId* = enum
    VERB_WALKTO = 1
    VERB_LOOKAT = 2
    VERB_TALKTO = 3
    VERB_PICKUP = 4
    VERB_OPEN = 5
    VERB_CLOSE = 6
    VERB_PUSH = 7
    VERB_PULL = 8
    VERB_GIVE = 9
    VERB_USE = 10
    VERB_DIALOG = 13

proc verbName*(id: VerbId): string =
  ## Gets the name of the function to call from a verb id.
  case id:
  of VERB_CLOSE:return "verbClose"
  of VERB_GIVE:return "verbGive"
  of VERB_LOOKAT:return "verbLookAt"
  of VERB_OPEN:return "verbOpen"
  of VERB_PICKUP:return "verbPickup"
  of VERB_PULL:return "verbPull"
  of VERB_PUSH:return "verbPush"
  of VERB_TALKTO:return "verbTalkTo"
  of VERB_WALKTO:return "verbWalkTo"
  of VERB_USE:return "verbUse"
  of VERB_DIALOG: return "dialog"

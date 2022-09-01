import sequtils
import ../prefs

type
  State* = ref object of RootObj
  StateManager = object
    states: seq[State]

method init*(self: State) {.base.} =
  discard

method deinit*(self: State) {.base.} =
  discard

method update*(self: State, elapsed: float) {.base.} =
  discard

proc push*(self: var StateManager, state: State) =
  self.states.add state
  state.init()

proc pop*(self: var StateManager): State =
  if self.states.len > 0:
    result = self.states.pop()
    result.deinit()

proc update*(self: var StateManager, elapsed: float) =
  for state in self.states.toSeq:
    state.update(elapsed)

var
  gStateManager: StateManager

proc pushState*(state: State) =
  gStateManager.push(state)

proc popState*(): State =
  result = gStateManager.pop()

proc popState*(num: int) =
  var n = num
  while n > 0 and gStateManager.states.len > 0:
    discard gStateManager.pop()
    dec n

proc updateState*() =
  let elapsed = tmpPrefs().gameSpeedFactor / 60'f32
  gStateManager.update(elapsed)

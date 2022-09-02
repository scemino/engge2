import sequtils
import ../prefs
import ../../sys/app

type
  MouseState* = object
    oldBtns, newBtns: MouseButtonMask
  State* = ref object of RootObj
  StateManager = object
    states: seq[State]
    mouseState: MouseState

proc click*(self: MouseState, btn = mbLeft): bool =
  btn notin self.oldBtns and btn in self.newBtns

proc pressed*(self: MouseState, btn = mbLeft): bool =
  btn in self.newBtns

proc released*(self: MouseState, btn = mbLeft): bool =
  btn in self.oldBtns and btn notin self.newBtns

method init*(self: State) {.base.} =
  discard

method deinit*(self: State) {.base.} =
  discard

method handleInput*(self: State, mouseState: MouseState) {.base.} =
  discard

method update*(self: State, elapsed: float) {.base.} =
  discard

method activate*(self: State) {.base.} =
  discard

method deactivate*(self: State) {.base.} =
  discard

proc push*(self: var StateManager, state: State) =
  if self.states.len > 0:
    self.states[^1].deactivate()
  self.states.add state
  state.init()
  state.activate()

proc pop*(self: var StateManager): State =
  if self.states.len > 0:
    result = self.states.pop()
    result.deinit()
  if self.states.len > 0:
    self.states[^1].activate()

proc update*(self: var StateManager, elapsed: float) =
  self.mouseState.newBtns = mouseBtns()
  let states = self.states.toSeq
  for i in 0..<states.len:
    let state = states[i]
    if i == states.len - 1:
      state.handleInput(self.mouseState)
    state.update(elapsed)
  self.mouseState.oldBtns = self.mouseState.newBtns

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

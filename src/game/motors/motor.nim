type 
  Motor* = ref object of RootObj
    isEnabled: bool

method init*(self: Motor) {.base.} =
  self.isEnabled = true

method disable*(self: Motor) {.base.} =
  self.isEnabled = false

method enabled*(self: Motor) : bool {.base.} =
  self.isEnabled

method update*(self: Motor, el: float) {.base, locks: "unknown".} =
  # override this base method
  raise newException(CatchableError, "Method without implementation override")

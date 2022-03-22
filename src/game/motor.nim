type 
  Motor* = ref object of RootObj
    enabled*: bool

method update*(self: Motor, el: float) {.base.} =
  # override this base method
  raise newException(CatchableError, "Method without implementation override")

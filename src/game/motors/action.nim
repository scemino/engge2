import motor

type ActionMotor = ref object of Motor
    action: proc() {.closure.}

proc newActionMotor*(action: proc(){.closure.}): Motor =
  result = ActionMotor(action: action)
  result.init()

method update*(self: ActionMotor, dt: float) =
  if self.enabled:
    self.action()
    self.disable()

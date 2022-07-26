import std/logging
import std/strformat
import std/sequtils
import motor

type SerialMotors = ref object of Motor
    motors: seq[Motor]

proc newSerialMotors*(motors: openArray[Motor]): Motor =
  result = SerialMotors(motors: motors.toSeq)
  result.init()

method update*(self: SerialMotors, dt: float) =
  if self.motors.len > 0:
    self.motors[0].update(dt)
    if not self.motors[0].enabled:
      info fmt"SerialMotors next"
      self.motors.del 0
  else:
    info fmt"SerialMotors is over"
    self.disable()
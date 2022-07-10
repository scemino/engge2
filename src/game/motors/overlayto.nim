import std/logging
import std/strformat
import motor
import ../room
import ../../gfx/color
import ../../util/tween
import ../../util/easing
import ../engine

type OverlayTo = ref object of Motor
  room: Room
  to: Color
  tween: Tween[Color]

proc newOverlayTo*(duration: float, room: Room, to: Color): OverlayTo =
  new(result)
  result.room = room
  result.to = to
  result.tween = newTween[Color](gEngine.room.overlay, to, duration, ikLinear)
  result.init()

method update(self: OverlayTo, el: float) =
  self.tween.update(el)
  self.room.overlay = self.tween.current()
  if not self.tween.running():
    self.disable()

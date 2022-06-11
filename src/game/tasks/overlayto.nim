import glm
import ../room
import task
import ../../gfx/color
import ../../util/tween
import ../../util/easing

type OverlayTo = ref object of Task
    room: Room
    tween: Tween[Color]

proc newOverlayTo*(duration: float, room: Room, frm, to: Color): OverlayTo =
  new(result)
  result.room = room
  result.tween = newTween[Color](room.overlay, to, duration, imLinear)

method update(self: OverlayTo, el: float): bool =
  self.tween.update(el)
  self.room.overlay = self.tween.current()
  not self.tween.running()
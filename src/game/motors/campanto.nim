import glm
import motor
import ../../util/tween
import ../../util/easing
import ../../util/vecutils
import ../../game/engine
import ../../game/room
import ../../gfx/graphics

type CameraPanTo = ref object of Motor
    tween: Tween[Vec2f]
    roomSize: Vec2i

proc newCameraPanTo*(duration: float, to: Vec2f, im: InterpolationMethod): CameraPanTo =
  new(result)
  let halfScreenSize = vec2f(gEngine.room.getScreenSize()) / 2.0f
  result.roomSize = gEngine.room.roomSize
  result.tween = newTween[Vec2f](cameraPos(), to - halfScreenSize, duration, im)
  result.init()

method update(self: CameraPanTo, dt: float) =
  self.tween.update(dt)
  gEngine.cameraAt(self.tween.current())
  if not self.tween.running():
    self.disable()

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
  var screenSize = gEngine.room.getScreenSize()
  result.roomSize = gEngine.room.roomSize
  result.tween = newTween[Vec2f](cameraPos(), to - vec2(screenSize.x.float32, screenSize.y.float32)/2.0f, duration, im)
  result.init()

method update(self: CameraPanTo, el: float) =
  self.tween.update(el)
  gEngine.cameraAt(self.tween.current())
  if not self.tween.running():
    self.disable()

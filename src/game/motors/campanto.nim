import glm
import motor
import ../../util/tween
import ../../util/easing
import ../../util/utils
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
  result.enabled = true

method update(self: CameraPanTo, el: float) =
  self.tween.update(el)
  gEngine.cameraAt(self.tween.current())
  self.enabled = self.tween.running()

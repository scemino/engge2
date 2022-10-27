import glm
import room
import ../gfx/recti
import ../gfx/graphics
import ../util/easing

type Camera* = object
  pos: Vec2f
  bounds*: Rectf
  moving*: bool
  init, target: Vec2f
  elapsed, time: float
  room*: Room
  follow*: Object
  function: easing_func

proc clamp(self: var Camera, at: Vec2f) =
  if not self.room.isNil:
    let roomSize = vec2f(self.room.roomSize)
    let screenSize = vec2f(self.room.getScreenSize())

    self.pos.x = clamp(at.x, screenSize.x / 2 + self.bounds.left, screenSize.x / 2 + self.bounds.right)
    self.pos.y = clamp(at.y, self.bounds.bottom, self.bounds.top - screenSize.y / 2)
    self.pos.x = clamp(at.x, screenSize.x / 2f, max(roomSize.x - screenSize.x / 2f, 0f))
    self.pos.y = clamp(at.y, screenSize.y / 2, max(roomSize.y - screenSize.y / 2, 0f))

proc `at=`*(self: var Camera, at: Vec2f) =
  let screenSize = vec2f(self.room.getScreenSize())
  self.pos = at
  self.clamp(self.pos)
  cameraPos(self.pos - screenSize / 2f)
  self.target = self.pos
  self.time = 0
  self.moving = false

proc `at`*(self: var Camera): Vec2f =
  self.pos

proc `isMoving`*(self: Camera): bool =
  self.moving

proc panTo*(self: var Camera, target: Vec2f, time: float, interpolation: InterpolationMethod) =
  if not self.isMoving:
    self.moving = true
    self.init = self.at
    self.elapsed = 0f
  self.function = easing(interpolation)
  self.target = target
  self.time = time

proc update*(self: var Camera, room: Room, follow: Object, elapsed: float) =
  self.room = room
  self.elapsed += elapsed
  let isMoving = self.elapsed < self.time

  if self.isMoving and not isMoving:
    self.moving = false
    self.time = 0f
    self.at = self.target

  if isMoving:
    let t = self.elapsed / self.time
    let d = self.target - self.init
    let pos = self.init + (d * self.function(t))

    self.clamp(pos)
    self.at = pos
    return

  if not follow.isNil and follow.node.visible and follow.room == room:
    let screen = vec2f(room.getScreenSize())
    let pos = follow.node.pos
    let margin = vec2(screen.x / 6f, screen.y / 6f)
    let cameraPos = self.at

    let d = pos - cameraPos
    let delta = d * elapsed
    let sameActor = self.follow == follow

    var x, y: float32
    if sameActor and pos.x > (cameraPos.x + margin.x):
      x = pos.x - margin.x
    elif sameActor and pos.x < (cameraPos.x - margin.x):
      x = pos.x + margin.x
    else:
      x = cameraPos.x + (if d.x > 0: min(delta.x, d.x) else: max(delta.x, d.x))
    if sameActor and (pos.y > (cameraPos.y + margin.y)):
      y = pos.y - margin.y
    elif sameActor and pos.y < (cameraPos.y - margin.y):
      y = pos.y + margin.y
    else:
      y = cameraPos.y + (if d.y > 0: min(delta.y, d.y) else: max(delta.y, d.y))
    self.at = vec2(x, y)
    if not sameActor and abs(pos.x - x) < 1f and abs(pos.y - y) < 1f:
      self.follow = follow

import glm

proc `*`*(value: float32, pos: Vec2f): Vec2f =
  vec2(pos.x * value, pos.y * value)

proc distanceSquared*(p1, p2: Vec2f): float =
  let dx = p1.x - p2.x
  let dy = p1.y - p2.y
  dx * dx + dy * dy

proc distance*(p1, p2: Vec2f): float =
  sqrt(distanceSquared(p1, p2))
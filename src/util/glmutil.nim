import glm

proc vec2f*(p: Vec2i): Vec2f =
  vec2(p.x.float32, p.y.float32)

proc vec2i*(p: Vec2f): Vec2i =
  vec2(p.x.int32, p.y.int32)

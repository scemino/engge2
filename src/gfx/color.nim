import glm

type Color* = Vec4f

proc rgb*(r,g,b: byte, a = 255): Color =
  vec4(r.float32/255f, g.float32/255f, b.float32/255f, a.float32/255f)

proc rgbf*(r,g,b: float32, a = 1'f32): Color =
  vec4(r, g, b, a)

proc rgbf*(c: Color, a = 1'f32): Color =
  vec4(c[0], c[1], c[2], a)

const
  Black* = rgb(0x0, 0x0, 0x0)
  White* = rgb(0xff, 0xff, 0xff)
  Red* = rgb(0xff, 0, 0)
  Green* = rgb(0, 0xff, 0)
  Blue* = rgb(0, 0, 0xff)
  Orange* = rgb(0xff, 0xa5, 0x00)
  LimeGreen* = rgb(0x32, 0xcd, 0x32)
  Gray* = rgb(0x80, 0x80, 0x80)
  Yellow* = rgb(0xff, 0xff, 0x00)

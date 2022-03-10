import std/[sequtils, sugar]
import glm
import nimgl/opengl
import color
import graphics
import ../app/room

proc vec2f*(p: Vec2i): Vec2f =
  vec2(p.x.float32, p.y.float32)

proc vec2i*(p: Vec2f): Vec2i =
  vec2(p.x.int32, p.y.int32)

proc drawLines*(pos: Vec2f, v: openArray[Vec2f], color: Color, loop = false) =
  var vertices = v.toSeq.map(v => newVertex(v.x, v.y, color)).toSeq
  for v in vertices.mitems:
    v.pos += pos
  noTexture()
  drawPrimitives(if loop: GL_LINE_LOOP else: GL_LINES, vertices)

proc drawLines*(pos: Vec2f, v: openArray[Vertex]) =
  var vertices = v.toSeq
  for v in vertices.mitems:
    v.pos += pos
  noTexture()
  gfxDrawLines(vertices)

proc drawLine*(pos: Vec2f, p1x, p1y, p2x, p2y: float32, color: Color) =
  drawLines(pos, [newVertex(p1x, p1y, color), newVertex(p2x, p2y, color)])

proc drawCross*(pos: Vec2f, color: Color, length = 8f) =
  let length_2 = length / 2f
  var vertices: array[4, Vertex] = [
      newVertex(-length_2, 0f, color),
      newVertex(length_2, 0f, color),
      newVertex(0f, -length_2, color),
      newVertex(0f, length_2, color)
  ]
  drawLines(pos, vertices)

proc drawArrow*(pos: Vec2f, dir: Direction, color: Color, length = 10f) =
  drawCross(pos, color, length)
  let length_4 = length / 4f
  case dir:
  of dBack:
    drawLine(pos, -length_4, -length_4, length_4, -length_4, color)
  of dFront:
    drawLine(pos, -length_4, length_4, length_4, length_4, color)
  of dRight:
    drawLine(pos, length_4, -length_4, length_4, length_4, color)
  of dLeft:
    drawLine(pos, -length_4, -length_4, -length_4, length_4, color)
  of dNone:
      discard
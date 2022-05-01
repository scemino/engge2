import std/[json, parseutils]
import glm
import ../gfx/recti

proc toBool*(jNode: JsonNode, key: string): bool {.inline.} =
  jNode.hasKey(key) and jNode[key].getInt == 1

proc parseRecti*(text: string): Recti =
  var x, y, x2, y2: int
  var i = 2
  i += parseInt(text, x, i) + 1
  i += parseInt(text, y, i) + 3
  i += parseInt(text, x2, i) + 1
  i += parseInt(text, y2, i)
  rect(x.int32, y.int32, (x2 - x).int32, (y2 - y).int32)

proc parseVec2i*(value: string): Vec2i =
  var x, y: int
  let tmp = parseInt(value, x, 1)
  discard parseInt(value, y, 2 + tmp)
  vec2(x.int32, y.int32)

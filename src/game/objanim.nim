import std/json
import glm
import ../util/jsonutil

type
  ObjectAnimation* = ref object of RootObj
    name*: string
    sheet*: string
    frames*: seq[string]
    layers*: seq[ObjectAnimation]
    triggers*: seq[string]
    offsets*: seq[Vec2i]
    loop*: bool
    fps*: float32
    flags*: int
    frameIndex*: int

proc parseObjectAnimation(jAnim: JsonNode): ObjectAnimation =
  new(result)
  if jAnim.hasKey("sheet"):
    result.sheet = jAnim["sheet"].getStr()
  result.name = jAnim["name"].getStr()
  result.loop = toBool(jAnim, "loop")
  result.fps = if jAnim.hasKey("fps") and (jAnim["fps"].kind == JFloat or jAnim["fps"].kind == JInt): jAnim["fps"].getFloat else: 0
  result.flags = if jAnim.hasKey("flags") and jAnim["flags"].kind ==
      JInt: jAnim["flags"].getInt else: 0
  if jAnim.hasKey("frames") and jAnim["frames"].kind == JArray:
    for jFrame in jAnim["frames"].items:
      let name = jFrame.getStr()
      result.frames.add(name)

  if jAnim.hasKey("layers") and jAnim["layers"].kind == JArray:
    for jLayer in jAnim["layers"].items:
      let layer = parseObjectAnimation(jLayer)
      result.layers.add(layer)

  if jAnim.hasKey("triggers") and jAnim["triggers"].kind == JArray:
    for jTrigger in jAnim["triggers"].items:
      result.triggers.add(jTrigger.getStr)
  
  if jAnim.hasKey("offsets") and jAnim["offsets"].kind == JArray:
    for jOffset in jAnim["offsets"].items:
      result.offsets.add(parseVec2i(jOffset.getStr))

proc parseObjectAnimations*(jAnims: JsonNode): seq[ObjectAnimation] =
  for jAnim in jAnims:
    result.add(parseObjectAnimation(jAnim))

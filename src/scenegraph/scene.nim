import node
import glm

type
  Scene* {.final.} = ref object of Node

proc newScene*(): Scene =
  new(result)
  result.scale = vec2(1.0f, 1.0f)

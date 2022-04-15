import node

type
  Scene* {.final.} = ref object of Node

proc newScene*(): Scene =
  new(result)
  result.init()
  result.visible = true

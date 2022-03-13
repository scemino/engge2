import glm
import sqnim

type
  Object* = object
    pos*: Vec2f
    sheet*: string
    anims*: seq[string]
    obj*: HSQOBJECT

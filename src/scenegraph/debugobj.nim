import glm
import node
import ../gfx/color
import ../gfx/graphics
import ../game/engine
import ../game/room

type
  DebugObject* = ref object of Node
    obj*: Object

proc newDebugObject*(obj: Object): DebugObject =
  result = DebugObject(obj: obj, zorder: -1000)
  result.init()

method drawCore(self: DebugObject, transf: Mat4f) =
  if not self.obj.isNil and self.obj.room == gEngine.room:
    gfxDrawQuad(gEngine.room.roomToScreen(self.obj.node.pos + self.obj.node.offset)-vec2f(2f, 2f), vec2f(4f, 4f), Red)

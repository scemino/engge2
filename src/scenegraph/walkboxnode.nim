import glm
import node
import ../game/engine
import ../game/room
import ../gfx/color
import ../gfx/graphics

type
  WalkboxMode* = enum
    None,
    Merged,
    All
  WalkboxNode* = ref object of Node
    mode*: WalkboxMode

proc newWalkboxNode*(): WalkboxNode =
  result = WalkboxNode(zorder: -1000)
  result.init()

method drawCore(self: WalkboxNode, transf: Mat4f) =
  if not gEngine.room.isNil:
    case self.mode:
    of WalkboxMode.All:
      let transf = translate(mat4(1f), vec3(-cameraPos(), 0f))
      for wb in gEngine.room.walkboxes:
        if wb.visible:
          let color = if wb.visible: Green else: Red
          var vertices: seq[Vertex]
          for p in wb.polygon:
            vertices.add newVertex(p.x.float32, p.y.float32, color)
          # cancel camera pos
          gfxDrawLineLoop(vertices, transf)
    of WalkboxMode.Merged:
      let transf = translate(mat4(1f), vec3(-cameraPos(), 0f))
      for wb in gEngine.room.mergedPolygon:
        let color = if wb.visible: Green else: Red
        var vertices: seq[Vertex]
        for p in wb.polygon:
          vertices.add newVertex(p.x.float32, p.y.float32, color)
        # cancel camera pos
        gfxDrawLineLoop(vertices, transf)
    of None:
      discard

import glm
import node
import ../game/room
import ../gfx/color
import ../gfx/graphics

type
  WalkboxMode* = enum
    None,
    Merged,
    All
  WalkboxNode* = ref object of Node
    room: Room
    mode*: WalkboxMode

proc newWalkboxNode*(room: Room): WalkboxNode =
  result = WalkboxNode(room: room)
  result.init()

method drawCore(self: WalkboxNode, transf: Mat4f) =
  case self.mode:
  of WalkboxMode.All:
    let transf = translate(mat4(1f), vec3(-cameraPos(), 0f))
    for wb in self.room.walkboxes:
      let color = if wb.visible: Green else: Red
      var vertices: seq[Vertex]
      for p in wb.polygon:
        vertices.add newVertex(p.x.float32, p.y.float32, color)
      # cancel camera pos
      gfxDrawLineLoop(vertices, transf)
  of WalkboxMode.Merged:
    let transf = translate(mat4(1f), vec3(-cameraPos(), 0f))
    for wb in self.room.mergedPolygon:
      var vertices: seq[Vertex]
      for p in wb.polygon:
        vertices.add newVertex(p.x.float32, p.y.float32, Green)
      # cancel camera pos
      gfxDrawLineLoop(vertices, transf)
  of None:
    discard

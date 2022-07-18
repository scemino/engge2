import glm
import node
import ../gfx/color
import ../gfx/graphics
import ../game/engine
import ../game/room
import ../game/motors/walkto

type
  PathNode* = ref object of Node

proc newPathNode*(): PathNode =
  result = PathNode(zorder: -1000)
  result.init()

method drawCore(self: PathNode, transf: Mat4f) =
  let actor = gEngine.actor
  if not actor.isNil:
    let walkTo = cast[WalkTo](actor.walkto)
    let path = walkTo.path
    if path.len > 0:
      var vertices: seq[Vertex]
      for v in path:
        vertices.add Vertex(pos: gEngine.room.roomToScreen(v), color: Yellow)
      gfxDrawLines(vertices)

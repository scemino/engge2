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
  if not actor.isNil and not actor.walkto.isNil:
    let walkTo = cast[WalkTo](actor.walkto)
    let path = walkTo.path
    if path.len > 0:
      var vertices: seq[Vertex]
      vertices.add Vertex(pos: gEngine.room.roomToScreen(actor.node.pos), color: Yellow)
      for v in path:
        let p = gEngine.room.roomToScreen(v)
        vertices.add Vertex(pos: p, color: Yellow)
        gfxDrawQuad(p-vec2f(2f, 2f), vec2f(4f, 4f), Yellow)
      gfxDrawLines(vertices)
  if not actor.isNil:
    gfxDrawQuad(gEngine.room.roomToScreen(actor.node.pos)-vec2f(2f, 2f), vec2f(4f, 4f), Red)

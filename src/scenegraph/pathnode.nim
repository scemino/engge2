import glm
import node
import ../gfx/color
import ../gfx/graphics
import ../game/engine
import ../game/room
import ../game/walkbox
import ../game/motors/walkto
import ../sys/app

type
  PathNode* = ref object of Node

proc newPathNode*(): PathNode =
  result = PathNode(zorder: -1000)
  result.init()

proc fixPos(pos: Vec2f): Vec2f =
  for wb in gEngine.room.mergedPolygon:
    if not wb.visible and wb.contains(pos):
      return wb.getClosestPointOnEdge(pos)
  for wb in gEngine.room.mergedPolygon:
    if wb.visible and not wb.contains(pos):
      return wb.getClosestPointOnEdge(pos)
  return pos

method drawCore(self: PathNode, transf: Mat4f) =
  let actor = gEngine.actor
  # draw actor path
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

  # draw graph nodes
  let graph = if gEngine.room.pathFinder.isNil: nil else: gEngine.room.pathFinder.graph
  if not graph.isNil:
    for v in graph.concaveVertices:
      gfxDrawQuad(gEngine.room.roomToScreen(vec2f(v)) - vec2f(2f, 2f), vec2f(4f, 4f), Yellow)

    # for edges in graph.edges:
    #   for edge in edges:
    #     let p1 = gEngine.room.roomToScreen(graph.nodes[edge.start])
    #     let p2 = gEngine.room.roomToScreen(graph.nodes[edge.to])
    #     var vertices = [Vertex(pos: p1, color: White), Vertex(pos: p2, color: White)]
    #     gfxDrawLines(vertices)

  # draw path from actor to mouse position
  if not actor.isNil:
    gfxDrawQuad(gEngine.room.roomToScreen(actor.node.pos)-vec2f(2f, 2f), vec2f(4f, 4f), Yellow)
    let scrPos = winToScreen(mousePos())
    let roomPos = gEngine.room.screenToRoom(scrPos)
    let p = fixPos(roomPos)
    gfxDrawQuad(gEngine.room.roomToScreen(p)-vec2f(4f, 4f), vec2f(8f, 8f), Yellow)

    # let path = gEngine.room.calculatePath(fixPos(actor.node.pos), p)
    # var vertices: seq[Vertex]
    # for v in path:
    #   let p = gEngine.room.roomToScreen(v)
    #   vertices.add Vertex(pos: p, color: Yellow)
    # gfxDrawLines(vertices)

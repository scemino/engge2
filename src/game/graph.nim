import std/algorithm
import std/sequtils
import glm
import walkbox
import ../util/indprioqueue

const Epsilon = 1e-9
type
  GraphEdge* = ref object of RootObj
    ## An edge is a part of a walkable area, it is used by a Graph.
    ## See also:
    ##  - PathFinder
    ##  - Graph
    start*: int  ## Index of the node in the graph representing the start of the edge.
    to*: int     ## Index of the node in the graph representing the end of the edge.
    cost*: float ## Cost of the edge in the graph.

  Graph* = ref object of RootObj
    ## A graph helps to find a path between two points.
    ## This class has been ported from http://www.groebelsloot.com/2016/03/13/pathfinding-part-2/
    ## and modified
    nodes*: seq[Vec2f]
    edges*: seq[seq[GraphEdge]]
    concaveVertices*: seq[Vec2i]

  AStar = ref object of RootObj
    graph: Graph
    spt: seq[GraphEdge] ## The Shortest Path Tree
    gCost: seq[float]   ## This array will store the G cost of each node
    fCost: seq[float]   ## This array will store the F cost of each node
    sf: seq[GraphEdge]  ## The Search Frontier

  PathFinder* = ref object of RootObj
    ## A PathFinder is used to find a walkable path within one or several walkboxes.
    walkboxes*: seq[Walkbox]
    graph*: Graph

  Segment = object
    start, to: Vec2f
    left, right, top, bottom: float32
    a, b, c: float32

proc newGraphEdge(start, to: int, cost: float): GraphEdge =
  GraphEdge(start: start, to: to, cost: cost)

proc newGraph*(graph: Graph): Graph =
  let nodes = graph.nodes.toSeq
  let concaveVertices = graph.concaveVertices.toSeq
  var edges: seq[seq[GraphEdge]]
  for e in graph.edges:
    var sEdges: seq[GraphEdge]
    for se in e:
      sEdges.add(newGraphEdge(se.start, se.to, se.cost))
    edges.add(sEdges)
  result = Graph(nodes: nodes, edges: edges, concaveVertices: concaveVertices)

proc distance*[N,T](v1,v2: Vec[N,T]): T = length(v2 - v1)

proc normalize(self: var Segment) =
  var z = sqrt(self.a * self.a + self.b * self.b)
  if abs(z) > Epsilon:
    self.a /= z
    self.b /= z
    self.c /= z

proc newSegment(start, to: Vec2f): Segment =
  result.start = start
  result.to = to
  result.left = min(start.x, to.x)
  result.right = max(start.x, to.x)
  result.top = min(start.y, to.y)
  result.bottom = max(start.y, to.y)
  result.a = start.y - to.y
  result.b = to.x - start.x
  result.c = -result.a * start.x - result.b * start.y
  result.normalize()

proc distance(self: Segment, p: Vec2f): float =
  self.a * p.x + self.b * p.y + self.c

proc edge*(self: Graph, start, to: int): GraphEdge =
  ## Gets the edge from 'from' index to 'to' index.
  for e in self.edges[start]:
    if e.to == to:
      return e

proc addNode*(self: var Graph, node: Vec2f) =
  self.nodes.add(node)
  self.edges.add(newSeq[GraphEdge]())

proc addEdge*(self: var Graph, edge: GraphEdge) =
  if self.edge(edge.start, edge.to).isNil:
    self.edges[edge.start].add(edge)
  if self.edge(edge.to, edge.start).isNil:
    let e = newGraphEdge(edge.to, edge.start, edge.cost)
    self.edges[edge.to].add(e)

proc inside(self: Walkbox, position: Vec2f, toleranceOnOutside = true): bool =
  ## Indicates whether or not the specified position is inside this walkbox.
  var point = position
  const epsilon = 1.0f

  # Must have 3 or more edges
  if self.polygon.len < 3:
    return false

  var oldPoint = vec2(self.polygon[^1])
  var oldSqDist = distanceSquared(oldPoint, point)

  for nPoint in self.polygon:
    let newPoint = vec2(nPoint)
    let newSqDist = distanceSquared(newPoint, point)

    if oldSqDist + newSqDist + 2.0f * sqrt(oldSqDist * newSqDist) - distanceSquared(newPoint, oldPoint) < epsilon:
      return toleranceOnOutside

    var left: Vec2f
    var right: Vec2f
    if newPoint.x > oldPoint.x:
      left = oldPoint
      right = newPoint
    else:
      left = newPoint
      right = oldPoint

    if left.x < point.x and point.x <= right.x and (point.y - left.y) * (right.x - left.x) < (right.y - left.y) * (point.x - left.x):
      result = not result

    oldPoint = newPoint
    oldSqDist = newSqDist

proc intersect_1d(a,b,c,d: float): bool =
  var
    a2 = a
    b2 = b
    c2 = c
    d2 = d
  if a2 > b2:
    swap(a2, b2)
  if c2 > d2:
    swap(c2, d2)
  max(a2, c2) <= min(b2, d2) + Epsilon

proc det(a,b,c,d: float): float =
  a * d - b * c

proc less(p1, p2: Vec2f): bool =
  p1.x < p2.x - Epsilon or abs(p1.x - p2.x) < Epsilon and p1.y < p2.y - Epsilon

proc betw(l,r,x: float): bool =
  min(l, r) <= x + Epsilon and x <= max(l, r) + Epsilon

proc lineSegmentsCross(a1,b1,c1,d1: Vec2f): bool =
  var
    a = a1
    b = b1
    c = c1
    d = d1
  if not intersect_1d(a.x, b.x, c.x, d.x) or not intersect_1d(a.y, b.y, c.y, d.y):
    return false

  var m = newSegment(a, b)
  var n = newSegment(c, d)
  var zn = det(m.a, m.b, n.a, n.b)

  if abs(zn) < Epsilon:
    if abs(m.distance(c)) > Epsilon or abs(n.distance(a)) > Epsilon:
      return false

    if less(b, a):
      swap(a, b)
    if less(d, c):
      swap(c, d)
    return true

  let lx = -det(m.c, m.b, n.c, n.b) / zn
  let ly = -det(m.a, m.c, n.a, n.c) / zn
  return betw(a.x, b.x, lx) and betw(a.y, b.y, ly) and betw(c.x, d.x, lx) and betw(c.y, d.y, ly)

proc newPathFinder*(walkboxes: seq[Walkbox]): PathFinder =
  PathFinder(walkboxes: walkboxes)

proc inLineOfSight(self: PathFinder, start, to: Vec2f): bool =
  const epsilon = 0.5f

  # Not in LOS if any of the ends is outside the polygon
  if not self.walkboxes[0].inside(start) or not self.walkboxes[0].inside(to):
    return false

  # In LOS if it's the same start and end location
  if length(start - to) < epsilon:
    return true

  # Not in LOS if any edge is intersected by the start-end line segment
  for walkbox in self.walkboxes:
    let size = walkbox.polygon.len
    for i in 0..<size:
      let v1 = vec2(walkbox.polygon[i])
      let v2 = vec2(walkbox.polygon[(i + 1) mod size])
      if not lineSegmentsCross(start, to, v1, v2):
        continue

      # In some cases a 'snapped' endpoint is just a little over the line due to rounding errors. So a 0.5 margin is used to tackle those cases.
      if distanceToSegment(start, v1, v2) > epsilon and distanceToSegment(to, v1, v2) > epsilon:
        return false

  # Finally the middle point in the segment determines if in LOS or not
  var v2 = (start + to) / 2.0f
  result = self.walkboxes[0].inside(v2)
  for i in 1..<self.walkboxes.len:
    if self.walkboxes[i].inside(v2, false):
      result = false

proc createGraph(self: PathFinder): Graph =
  result = Graph()
  for walkbox in self.walkboxes:
    if walkbox.polygon.len > 2:
      let visible = walkbox.visible
      for i in 0..<walkbox.polygon.len:
        if walkbox.concave(i) == visible:
          let vertex = walkbox.polygon[i]
          result.concaveVertices.add(vertex)
          result.addNode(vec2f(vertex))

  for i in 0..<result.concaveVertices.len:
    for j in 0..<result.concaveVertices.len:
      let c1 = vec2(result.concaveVertices[i])
      let c2 = vec2(result.concaveVertices[j])
      if self.inLineOfSight(c1, c2):
        let d = distance(c1, c2)
        result.addEdge(newGraphEdge(i, j, d))

proc newAStar(graph: Graph): AStar =
  AStar(graph: graph, fCost: newSeq[float](graph.nodes.len), gCost: newSeq[float](graph.nodes.len), spt: newSeq[GraphEdge](graph.nodes.len), sf: newSeq[GraphEdge](graph.nodes.len))

proc search(self: AStar, source, target: int) =
  var pq = newIndexedPriorityQueue(addr self.fCost)
  pq.insert(source)
  while pq.len > 0:
    let NCN = pq.pop()
    self.spt[NCN] = self.sf[NCN]
    if NCN != target:
      for edge in self.graph.edges[NCN]:
        let Hcost = length(self.graph.nodes[edge.to] - self.graph.nodes[target])
        let Gcost = self.gCost[NCN] + edge.cost
        if self.sf[edge.to].isNil:
          self.fCost[edge.to] = Gcost + Hcost
          self.gCost[edge.to] = Gcost
          pq.insert(edge.to)
          self.sf[edge.to] = edge
        elif Gcost < self.gCost[edge.to] and self.spt[edge.to].isNil:
          self.fCost[edge.to] = Gcost + Hcost
          self.gCost[edge.to] = Gcost
          pq.reorderUp()
          self.sf[edge.to] = edge

proc getPath(graph: Graph, source, target: int): seq[int] =
  let astar = newAStar(graph)
  if target >= 0:
    astar.search(source, target)
    var nd = target
    result.add(nd)
    while nd != source and not astar.spt[nd].isNil:
      nd = astar.spt[nd].start
      result.add(nd)
    result.reverse()

proc calculatePath*(self: PathFinder, start, to: Vec2f): seq[Vec2f] =
  if self.walkboxes.len > 0:
     # find the walkbox where the actor is and put it first
    for i in 0..<self.walkboxes.len:
      let wb = self.walkboxes[i]
      if wb.inside(start) and i != 0:
        swap(self.walkboxes[0], self.walkboxes[i])
        break

    # if no walkbox has been found => find the nearest walkbox
    if not self.walkboxes[0].inside(start):
      var dists = newSeq[float](self.walkboxes.len)
      for i in 0..<self.walkboxes.len:
        let wb = self.walkboxes[i]
        dists[i] = distance(wb.getClosestPointOnEdge(start), start)

      let index = minIndex(dists)
      if index != 0:
        swap(self.walkboxes[0], self.walkboxes[index])

    if self.graph.isNil:
      self.graph = self.createGraph()

    # create new node on start position
    var walkgraph = newGraph(self.graph)
    var start = start
    var to = to
    let startNodeIndex = walkgraph.nodes.len

    for i in 1..<self.walkboxes.len:
      let wb = self.walkboxes[i]
      if wb.inside(start):
        start = self.walkboxes[i].getClosestPointOnEdge(start)
      if wb.inside(to):
        to = self.walkboxes[i].getClosestPointOnEdge(to)

    # if destination is not inside current walkable area, then get the closest point
    let wb = self.walkboxes[0]
    if wb.visible and not wb.contains(to):
      to = wb.getClosestPointOnEdge(to)

    walkgraph.addNode(start)

    for i in 0..<walkgraph.concaveVertices.len:
      let c = vec2(walkgraph.concaveVertices[i])
      if self.inLineOfSight(start, c):
        walkgraph.addEdge(newGraphEdge(startNodeIndex, i, distance(start, c)))

    # create new node on end position
    let endNodeIndex = walkgraph.nodes.len
    walkgraph.addNode(to)

    for i in 0..<walkgraph.concaveVertices.len:
      let c = vec2(walkgraph.concaveVertices[i])
      if self.inLineOfSight(to, c):
        walkgraph.addEdge newGraphEdge(i, endNodeIndex, distance(to, c))

    if self.inLineOfSight(start, to):
      walkgraph.addEdge newGraphEdge(startNodeIndex, endNodeIndex, distance(start, to))

    let indices = getPath(walkgraph, startNodeIndex, endNodeIndex)
    for i in indices:
      result.add(walkgraph.nodes[i])

when isMainModule:
  var p: PathFinder
  echo p.calculatePath(vec2(0f, 0f), vec2(2f, 2f))
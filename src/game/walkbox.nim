import std/parseutils
import glm
import ../polyBool/polyBool

type Walkbox* = object
  ## Represents an area where an actor can or cannot walk
  polygon*: seq[Vec2i]
  name*: string
  visible*: bool

proc parseWalkbox*(text: string): Walkbox =
  var points: seq[Vec2i]
  var i = 1
  while i < text.len:
    var x, y: int
    i += parseInt(text, x, i) + 1
    i += parseInt(text, y, i) + 3
    var p = vec2(x.int32, y.int32)
    points.add(p)
  Walkbox(polygon: points, visible: true)

proc toPolygon(walkbox: Walkbox): Polygon =
  result.addRegion()
  for p in walkbox.polygon:
    result.addVertex p.x.float, p.y.float

proc mergePoly(walkboxes: openArray[Walkbox]): Polygon =
  ## Merge all walkboxes in 1 polygon.
  if walkboxes.len > 0:
    var polygons: seq[Polygon]
    for wb in walkboxes:
      polygons.add toPolygon(wb)
    
    var polyBool = initPolyBool()
    var segments = polyBool.segments(polygons[0])
    for i in 1..<polygons.len:
      if walkboxes[i].visible:
        var seg2 = polyBool.segments(polygons[i])
        var comb = polyBool.combine(segments, seg2)
        segments = polyBool.selectUnion(comb)
    for i in 1..<polygons.len:
      if not walkboxes[i].visible:
        var seg2 = polyBool.segments(polygons[i])
        var comb = polyBool.combine(segments, seg2)
        segments = polyBool.selectDifference(comb)
    result = polyBool.polygon(segments)

proc merge*(walkboxes: openArray[Walkbox]): seq[Walkbox] =
  var poly = mergePoly(walkboxes)
  for region in poly.regions:
    var pts: seq[Vec2i]
    for p in region:
      pts.add(vec2(p.x.int32,p.y.int32))
    result.add Walkbox(polygon: pts)

proc concave*(self: Walkbox, vertex: int): bool =
  let current = self.polygon[vertex]
  let next = self.polygon[(vertex + 1) mod self.polygon.len]
  let previous = self.polygon[if vertex == 0: self.polygon.len - 1 else: vertex - 1]

  let left = vec2(current.x - previous.x, current.y - previous.y)
  let right = vec2(next.x - current.x, next.y - current.y)

  let cross = (left.x * right.y) - (left.y * right.x)
  cross < 0

proc distanceSquared*(v1, v2: Vec2f): float =
  var dx = v1.x - v2.x
  var dy = v1.y - v2.y
  dx * dx + dy * dy

proc vec2*(v: Vec2i): Vec2f =
  vec2(v.x.float32, v.y.float32)

proc vec2*(x, y: float): Vec2f =
  vec2(x.float32, y.float32)

proc distanceToSegmentSquared(p, v, w: Vec2f): float =
  var l2 = distanceSquared(v, w)
  if l2 == 0:
    distanceSquared(p, v)
  else:
    var t = ((p.x - v.x) * (w.x - v.x) + (p.y - v.y) * (w.y - v.y)) / l2
    if t < 0:
      distanceSquared(p, v)
    elif t > 1:
      distanceSquared(p, w)
    else:
      distanceSquared(p, vec2(v.x + t * (w.x - v.x), v.y + t * (w.y - v.y)))

proc distanceToSegment*(p,v,w: Vec2f): float =
  sqrt(distanceToSegmentSquared(p, v, w))

proc getClosestPointOnEdge*(self: Walkbox, p3: Vec2f) : Vec2f =
  var vi1 = -1
  var vi2 = -1
  var minDist = 100000.0

  for i in 0..<self.polygon.len:
    let dist = distanceToSegment(p3, vec2(self.polygon[i]), vec2(self.polygon[(i + 1) mod self.polygon.len()]))
    if dist < minDist:
      minDist = dist
      vi1 = i
      vi2 = (i + 1) mod self.polygon.len

  var p1 = vec2(self.polygon[vi1])
  var p2 = vec2(self.polygon[vi2])

  var x1 = p1.x
  var y1 = p1.y
  var x2 = p2.x
  var y2 = p2.y
  var x3 = p3.x
  var y3 = p3.y

  var u = (((x3 - x1) * (x2 - x1)) + ((y3 - y1) * (y2 - y1))) / (((x2 - x1) * (x2 - x1)) + ((y2 - y1) * (y2 - y1)))

  var xu = x1 + u * (x2 - x1)
  var yu = y1 + u * (y2 - y1)

  if u < 0:
    return vec2(x1, y1)
  if u > 1:
    return vec2(x2, y2)
  return vec2(xu, yu)
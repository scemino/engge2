import std/parseutils
import std/sequtils
import glm
import clipper

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
    let p = vec2(x.int32, y.int32)
    points.add(p)
  Walkbox(polygon: points, visible: true)

proc toPolygon(walkbox: Walkbox): Path =
  for p in walkbox.polygon:
    result.add IntPoint(X: p.x, Y: p.y)

proc mergePolygons(walkboxes: openArray[Walkbox]): Paths =
  if walkboxes.len > 0:
    var subjects, clips: Paths
    for wb in walkboxes:
      if wb.visible:
        subjects.add wb.toPolygon
      else:
        clips.add wb.toPolygon
    result = Union(subjects, clips, pftEvenOdd)

proc toWalkbox(polygon: Path): Walkbox =
  var pts: seq[Vec2i]
  for p in polygon:
    pts.add vec2(p.X.int32, p.Y.int32)
  Walkbox(visible: Orientation(polygon), polygon: pts)

iterator toWalkboxes(polygons: Paths): Walkbox =
  for p in polygons:
    yield p.toWalkbox

proc merge*(walkboxes: openArray[Walkbox]): seq[Walkbox] =
  mergePolygons(walkboxes).toWalkboxes().toSeq

proc concave*(self: Walkbox, vertex: int): bool =
  let current = self.polygon[vertex]
  let next = self.polygon[(vertex + 1) mod self.polygon.len]
  let previous = self.polygon[if vertex == 0: self.polygon.len - 1 else: vertex - 1]

  let left = vec2(current.x - previous.x, current.y - previous.y)
  let right = vec2(next.x - current.x, next.y - current.y)

  let cross = (left.x * right.y) - (left.y * right.x)
  result = if self.visible: cross < 0 else: cross >= 0

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

proc contains*(self: Walkbox, pos: Vec2f, toleranceOnOutside = true): bool =
  ## Indicates whether or not the specified position is inside this walkbox.
  var point = pos
  const epsilon = 1.0f

  # Must have 3 or more edges
  if self.polygon.len < 3:
    return false

  var oldPoint = vec2f(self.polygon[^1])
  var oldSqDist = distanceSquared(oldPoint, point)

  for nPoint in self.polygon:
    let newPoint = vec2(nPoint)
    let newSqDist = distanceSquared(newPoint, point)

    if oldSqDist + newSqDist + 2.0f * sqrt(oldSqDist * newSqDist) - distanceSquared(newPoint, oldPoint) < epsilon:
      return toleranceOnOutside;

    var left, right: Vec2f
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

when isMainModule:
  let wbTexts = [
    "{91,113};{173,113};{186,104};{329,104};{331,109};{412,109};{416,102};{494,102};{506,97};{532,94};{554,90};{660,66};{7,70};{8,86};{25,90};{19,104}",
    "{730,114};{732,109};{554,90};{532,94}",
    "{730,114};{731,121};{737,125};{750,120};{746,114};{732,109}",
    "{693,130};{695,132};{737,125};{731,121}",
    "{639,136};{695,132};{693,130};{638,134}",
    "{198,116};{197,113};{190,112};{186,104};{173,113}",
    "{699,164};{706,164};{636,153};{625,151};{616,147};{609,148};{620,152};{633,154}",
    "{609,148};{616,147};{621,142};{639,136};{638,134};{613,143}",
    "{658,185};{663,184};{666,181};{679,177};{699,170};{706,164};{699,164};{696,168};{675,175};{664,178}",
    "{747,198};{761,203};{766,203};{747,196};{721,195};{682,190};{663,184};{658,185};{679,192};{720,197}"]
  var wbs: seq[Walkbox]
  for wbText in wbTexts:
    wbs.add parseWalkbox(wbText)
  let sol = mergePolygons(wbs).toWalkboxes().toSeq
  echo sol
  echo sol.len
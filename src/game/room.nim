import glm
import sqnim
import std/[json, parseutils, options, sequtils, streams, algorithm, sugar, strformat]
import ../gfx/recti
import ../gfx/spritesheet
import ../gfx/texture
import ../gfx/image
import ../gfx/graphics
import ../gfx/color
import motor

type
  ScalingValue* = object
    scale*: float
    y*: int
  Scaling* = object
    values*: seq[ScalingValue]
    trigger*: string
  Layer* = object
    names*: seq[string]
    parallax*: Vec2f
    zsort*: float
    visible*: bool
  Direction* = enum
    dNone,
    dFront,
    dBack,
    dLeft,
    dRight
  ObjectType* = enum
    otNone,
    otProp,
    otSpot,
    otTrigger
  AnimState = enum
    asPause,
    asPlay
  Walkbox* = object
    polygon*: seq[Vec2i]
    name*: string
    visible*: bool
  ObjectAnimation* = ref object of RootObj
    name*: string
    frames*: seq[string]
    layers*: seq[ObjectAnimation]
    triggers*: seq[string]
    loop*: bool
    fps*: float32
    flags*: int
    frameIndex*: int
  Object* = ref object of RootObj
    name*: string
    visible*: bool
    pos*: Vec2f
    usePos*: Vec2f
    useDir*: Direction
    hotspot*: Recti
    objType*: ObjectType
    animations*: seq[ObjectAnimation]
    animationIndex*: int
    frameIndex: int
    zsort*: int32
    state: AnimState
    elapsedMs: float
    color*: Color
    alphaTo*: Motor
    table*: HSQOBJECT
    touchable*: bool
    room*: Room
  Room* = ref object of RootObj
    name*: string
    sheet*: string
    roomSize*: Vec2i
    fullscreen*: int32
    height*: int32
    layers*: seq[Layer]
    walkboxes*: seq[Walkbox]
    scalings*: seq[Scaling]
    objects*: seq[Object]
    texture: Texture
    spriteSheet*: SpriteSheet
    table*: HSQOBJECT
    overlay*: Color
  RoomParser = object
    input: Stream
    filename: string

proc newLayer(names: seq[string], parallax: Vec2f, zsort: float): Layer =
  Layer(names: names, parallax: parallax, zsort: zsort, visible: true)

proc toBool(jNode: JsonNode, key: string): bool {.inline.} =
  jNode.hasKey(key) and jNode[key].getInt == 1

proc parseVec2i(value: string): Vec2i =
  var x, y: int
  let tmp = parseInt(value, x, 1)
  discard parseInt(value, y, 2 + tmp)
  vec2(x.int32, y.int32)

proc parsePolygon(text: string): Walkbox =
  var points: seq[Vec2i]
  var i = 1
  while i < text.len:
    var x, y: int
    i += parseInt(text, x, i) + 1
    i += parseInt(text, y, i) + 3
    var p = vec2(x.int32, y.int32)
    points.add(p)
  Walkbox(polygon: points, visible: true)

proc parseRecti(text: string): Recti =
  var x, y, x2, y2: int
  var i = 2
  i += parseInt(text, x, i) + 1
  i += parseInt(text, y, i) + 3
  i += parseInt(text, x2, i) + 1
  i += parseInt(text, y2, i)
  rect(x.int32, y.int32, (x2 - x).int32, (y2 - y).int32)

proc parseScaling(node: JsonNode): Scaling =
  assert(node.kind == JArray)
  var
    scale: float
    y: int
  for item in node.items:
    assert(item.kind == JString)
    var i = 0
    let v = item.getStr
    i += parseFloat(v, scale, i) + 1
    i += parseInt(v, y, i)
    result.values.add(ScalingValue(scale: scale, y: y))

proc parseObjectAnimation(jAnim: JsonNode): ObjectAnimation =
  new(result)
  result.name = jAnim["name"].getStr()
  result.loop = toBool(jAnim, "loop")
  result.fps = if jAnim.hasKey("fps") and jAnim["fps"].kind == JFloat: jAnim["fps"].getFloat else: 0
  result.flags = if jAnim.hasKey("flags") and jAnim["flags"].kind ==
      JInt: jAnim["flags"].getInt else: 0
  if jAnim.hasKey("frames") and jAnim["frames"].kind == JArray:
    for jFrame in jAnim["frames"].items:
      let name = jFrame.getStr()
      result.frames.add(name)

  if jAnim.hasKey("layers") and jAnim["layers"].kind == JArray:
    for jLayer in jAnim["layers"].items:
      let layer = parseObjectAnimation(jLayer)
      result.layers.add(layer)

  if jAnim.hasKey("triggers") and jAnim["triggers"].kind == JArray:
    for jTrigger in jAnim["triggers"].items:
      result.triggers.add(jTrigger.getStr)

proc parseObjectAnimations*(jAnims: JsonNode): seq[ObjectAnimation] =
  for jAnim in jAnims:
    result.add(parseObjectAnimation(jAnim))

proc toObjectType(jObject: JsonNode): ObjectType =
  if toBool(jObject, "prop"):
    return otProp
  if toBool(jObject, "spot"):
    return otSpot
  if toBool(jObject, "trigger"):
    return otTrigger
  return otNone

proc parseUseDir(node: JsonNode): Direction =
  case node.getStr:
  of "DIR_FRONT":
    return dFront
  of "DIR_BACK":
    return dBack
  of "DIR_LEFT":
    return dLeft
  of "DIR_RIGHT":
    return dRight
  doAssert(false, "invalid use direction")

proc open*(self: var RoomParser, input: Stream, filename: string) =
  assert(input != nil)
  self.input = input
  self.filename = filename

proc close*(self: var RoomParser) {.inline.} =
  self.input.close()

proc parseParallax(node: JsonNode): Vec2f =
  if node.kind == JFloat:
    return vec2(node.getFloat.float32, 1f)
  let s = node.getStr
  var x, y: float
  let o = parseFloat(s, x, 1)
  discard parseFloat(s, y, 2 + o)
  return vec2(x.float32, y.float32)

proc getNode(node: JsonNode, key: string): Option[JsonNode] =
  if node.hasKey(key): some(node[key]) else: none(JsonNode)

proc parseRoom(self: var RoomParser): Room =
  let jRoom = parseJson(self.input, self.filename)
  let name = jRoom["name"].getStr
  let sheet = jRoom["sheet"].getStr

  let roomSize = parseVec2i(jRoom["roomsize"].getStr)
  let height = if jRoom.hasKey "height": jRoom["height"].getInt() else: roomSize.y
  let fullscreen = jRoom["fullscreen"].getInt

  new(result)
  result.name = name
  result.sheet = sheet
  result.height = height.int32
  result.roomSize =  roomSize
  result.fullscreen = fullscreen.int32
  result.overlay = Transparent

  # backgrounds
  var names: seq[string]
  if jRoom["background"].kind == JString:
    names.add(jRoom["background"].getStr)
  else:
    names.add(jRoom["background"].items().toSeq.mapIt(it.getStr).toSeq)
  let layer = newLayer(names, vec2(1f, 1f), 0)
  result.layers.add(layer)

  # layers
  if jRoom.hasKey("layers"):
    for jLayer in jRoom["layers"].items():
      names.setLen(0)
      let parallax = parseParallax(jLayer["parallax"])
      let zsort = jLayer["zsort"].getFloat
      if jLayer["name"].kind == JArray:
        for jName in jLayer["name"].items():
          names.add(jName.getStr())
      elif jLayer["name"].kind == JString:
        names.add(jLayer["name"].getStr)
      let layer = newLayer(names, parallax, zsort)
      result.layers.add(layer)
  result.layers.sort((x, y) => cmp(y.zsort, x.zsort))

  # walkboxes
  if jRoom.hasKey("walkboxes"):
    for jWalkbox in jRoom["walkboxes"].items():
      var walkbox = parsePolygon(jWalkbox["polygon"].getStr)
      if jWalkbox.hasKey("name") and jWalkbox["name"].kind == JString:
        walkbox.name = jWalkbox["name"].getStr
      result.walkboxes.add(walkbox)

  # objects
  if jRoom.hasKey("objects"):
    for jObject in jRoom["objects"]:
      var obj = new(Object)
      obj.name = jObject["name"].getStr
      obj.pos = vec2f(parseVec2i(jObject["pos"].getStr))
      obj.usePos = vec2f(parseVec2i(jObject["usepos"].getStr))
      let useDir = jObject.getNode("usedir")
      obj.useDir = if useDir.isSome: parseUseDir(useDir.get) else: dNone
      obj.hotspot = parseRecti(jObject["hotspot"].getStr)
      obj.zsort = jObject["zsort"].getInt().int32
      obj.objType = toObjectType(jObject)
      obj.touchable = true
      obj.visible = true
      obj.color = White
      if jObject.hasKey("animations"):
        obj.animations = parseObjectAnimations(jObject["animations"])
      result.objects.add(obj)

  # scalings
  if jRoom.hasKey("scaling"):
    let jScalings = jRoom["scaling"]
    if jScalings[0].kind == JString:
      result.scalings.add(parseScaling(jScalings))
    else:
      for jScaling in jScalings:
        var scaling = parseScaling(jScaling["scaling"])
        if jScaling.hasKey("trigger") and jScaling["trigger"].kind == JString:
          scaling.trigger = jScaling["trigger"].getStr()
        result.scalings.add(scaling)

  result.spriteSheet = loadSpriteSheet(result.sheet & ".json")
  result.texture = newTexture(newImage(result.spriteSheet.meta.image))

proc parseRoom*(s: Stream, filename: string = ""): Room =
  ## Parses from a stream `s` into a `Room`. `filename` is only needed
  ## for nice error messages.
  ## This closes the stream `s` after it's done.
  var p: RoomParser
  p.open(s, filename)
  try:
    result = p.parseRoom()
  finally:
    p.close()

proc parseRoom*(buffer: string): Room =
  result = parseRoom(newStringStream(buffer), "input")

proc getScreenSize(self: var Room, roomHeight: int): Vec2i =
  case roomHeight:
  of 128: vec2(320'i32, 180'i32)
  of 172: vec2(428'i32, 240'i32)
  of 256: vec2(640'i32, 360'i32)
  else: vec2(self.roomSize.x, roomHeight.int32)

func first*[T](s: openArray[T], f: proc (item: T): bool): Option[T] =
  for itm in items(s):
    if f(itm):
      return some(itm)

proc getFrame*(frames: seq[SpriteSheetFrame], name: string): SpriteSheetFrame =
  frames.first(proc (s: SpriteSheetFrame):bool = s.name == name).get

proc drawLayers(self: var Room, pred: proc (x: float): bool) =
  let size = self.spriteSheet.meta.size
  let camPos = cameraPos()
  for layer in self.layers:
    if layer.visible and pred(layer.zsort):
      var pos = -camPos * layer.parallax
      for name in layer.names:
        let item = self.spriteSheet.frames.getFrame(name)
        let frame = item.frame
        let off = vec2(item.spriteSourceSize.x.float32, (self.roomSize.y - item.spriteSourceSize.y - item.spriteSourceSize.h).float32)
        gfxDrawSprite(pos + off, frame / size, self.texture)
        pos.x += frame.w.float32

proc render*(self: var Room) =
  let screenSize = self.getScreenSize(self.height)
  camera(screenSize.x.float32, screenSize.y.float32)
  
  let camPos = cameraPos()
  let size = self.spriteSheet.meta.size

  # draw background layers
  self.drawLayers(x => x >= 0)

  # draw objects
  var objects = self.objects.sorted((x,y) => cmp(y.zsort, x.zsort))
  var pos = -camPos
  for obj in objects:
    if obj.visible and obj.animations.len > 0 and obj.animationIndex >= 0 and obj.animationIndex < obj.animations.len:
      let anim = obj.animations[obj.animationIndex].unsafeAddr
      if anim.frames.len > 0 and obj.frameIndex >= 0 and obj.frameIndex < anim.frames.len:
        let name = anim.frames[obj.frameIndex]
        if name != "null":
          try:
            let item = self.spriteSheet.frames.getFrame(name)
            let frame = item.frame
            let off = vec2(
              item.spriteSourceSize.x.float32 - item.sourceSize.x.float32 / 2'f32, 
              item.sourceSize.y.float32 / 2'f32 - item.spriteSourceSize.y.float32 - item.spriteSourceSize.h.float32)
            let objPos = vec2(obj.pos.x.float32, obj.pos.y.float32)
            gfxDrawSprite(pos + objPos + off, frame / size, self.texture, obj.color)
          except:
            quit fmt"Failed to render frame {name} for obj {obj.name}"

  # draw foreground layers
  self.drawLayers(x => x < 0)  

proc play*(self: Object) =
  self.elapsedMs = 0
  self.state = asPlay
  self.frameIndex = 0

proc pause*(self: Object) =
  self.state = asPause

proc update*(self: Object, elapsedSec: float) =
  if not self.alphaTo.isNil and self.alphaTo.enabled:
    self.alphaTo.update(elapsedSec)
    
  if self.visible and self.animations.len > 0 and self.animationIndex >= 0 and self.animationIndex < self.animations.len:
    let animation = self.animations[self.animationIndex]
    if animation.frames.len > 0:
      if self.frameIndex == -1:
        self.frameIndex = animation.frames.len - 1
      if self.state != asPause:
        if self.frameIndex >= animation.frames.len:
          self.frameIndex = 0
        else:
          self.elapsedMs += elapsedSec*1000f
          var fps = animation.fps
          if fps == 0:
            fps = 10
          let frameTime = 1000f / fps.float
          if self.elapsedMs > frameTime:
            self.elapsedMs -= frameTime
            if animation.loop or self.frameIndex != animation.frames.len - 1:
              self.frameIndex = (self.frameIndex + 1) mod animation.frames.len
            else:
              self.pause()

proc update*(self: var Room, elapsedSec: float) = 
  for obj in self.objects.mitems:
    obj.update(elapsedSec)

proc distanceSquared(vector1, vector2: Vec2f): float =
  let dx = vector1.x - vector2.x
  let dy = vector1.y - vector2.y
  dx * dx + dy * dy

proc isInside*(self: Walkbox, pos: Vec2f, toleranceOnOutside = true): bool =
  var point = pos
  const epsilon = 1f
  result = false

  # Must have 3 or more edges
  if self.polygon.len < 3:
    return false

  var oldPoint = vec2f(self.polygon[^1])
  var oldSqDist = distanceSquared(oldPoint, point)

  for nPoint in self.polygon:
    let newPoint = vec2f(nPoint)
    let newSqDist = distanceSquared(newPoint, point)

    if oldSqDist + newSqDist + 2.0f * sqrt(oldSqDist * newSqDist) - distanceSquared(newPoint, oldPoint) < epsilon:
      return toleranceOnOutside

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

proc distanceToSegmentSquared(p, v, w: Vec2f): float =
  let l2 = distanceSquared(v, w)
  if l2 == 0:
    return distanceSquared(p, v)
  let t = ((p.x - v.x) * (w.x - v.x) + (p.y - v.y) * (w.y - v.y)) / l2
  if t < 0:
    return distanceSquared(p, v)
  if t > 1:
    return distanceSquared(p, w)
  distanceSquared(p, vec2f(v.x + t * (w.x - v.x), v.y + t * (w.y - v.y)))

proc distanceToSegment*(p, v, w: Vec2f): float =
  sqrt(distanceToSegmentSquared(p, v, w))

proc getClosestPointOnEdge*(self: Walkbox, p3: Vec2f): Vec2f =
  var vi1 = -1
  var vi2 = -1
  var minDist = 100000f

  for i in 0..<self.polygon.len:
    let dist = distanceToSegment(p3, vec2f(self.polygon[i]), vec2f(self.polygon[(i + 1) mod self.polygon.len]))
    if dist < minDist:
      minDist = dist
      vi1 = i
      vi2 = (i + 1) mod self.polygon.len

  let p1 = self.polygon[vi1]
  let p2 = self.polygon[vi2]

  let x1 = p1.x.float32
  let y1 = p1.y.float32
  let x2 = p2.x.float32
  let y2 = p2.y.float32
  let x3 = p3.x.float32
  let y3 = p3.y.float32

  let u = (((x3 - x1) * (x2 - x1)) + ((y3 - y1) * (y2 - y1))) / (((x2 - x1) * (x2 - x1)) + ((y2 - y1) * (y2 - y1)))

  let xu = x1 + u * (x2 - x1)
  let yu = y1 + u * (y2 - y1)

  if u < 0:
    vec2(x1, y1)
  elif u > 1:
     vec2(x2, y2)
  else:
    vec2(xu, yu)
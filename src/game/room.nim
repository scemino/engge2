import std/[json, parseutils, options, sequtils, streams, algorithm, sugar, strformat, logging]
import glm
import sqnim
import squtils
import ../gfx/recti
import ../gfx/spritesheet
import ../gfx/texture
import ../gfx/image
import ../gfx/color
import ../scenegraph/spritenode
import motor

type
  Facing* = enum
    FACE_RIGHT = 1
    FACE_LEFT = 2
    FACE_FRONT = 4
    FACE_BACK = 8
  ScalingValue* = object
    scale*: float
    y*: int
  Scaling* = object
    values*: seq[ScalingValue]
    trigger*: string
  Layer* = ref object of RootObj
    names*: seq[string]
    parallax*: Vec2f
    zsort*: int
    visible*: bool
    objects*: seq[Object]
    room: Room
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
    n: string
    visible*: bool
    pos*: Vec2f
    rotation*: float
    usePos*: Vec2f
    useDir*: Direction
    hotspot*: Recti
    objType*: ObjectType
    anims*: seq[ObjectAnimation]
    animIndex*: int
    frameIndex: int
    zsort*: int32
    state: AnimState
    elapsedMs: float
    color*: Color
    alphaTo*: Motor
    table*: HSQOBJECT
    touchable*: bool
    r: Room
    spriteSheet*: SpriteSheet
    texture*: Texture
    facing*: Facing
    renderOffset*: Vec2f
    walkSpeed*: Vec2f
    parent*: string
    node*: SpriteNode
  Room* = ref object of RootObj
    name*: string
    sheet*: string
    roomSize*: Vec2i
    fullscreen*: int32
    height*: int32
    layers*: seq[Layer]
    walkboxes*: seq[Walkbox]
    scalings*: seq[Scaling]
    texture*: Texture
    spriteSheet*: SpriteSheet
    table*: HSQOBJECT
    overlay*: Color
  RoomParser = object
    input: Stream
    filename: string

proc `getSpriteSheet`*(self: Object): SpriteSheet =
  if self.spriteSheet.isNil:
    self.r.spriteSheet
  else:
    self.spriteSheet

proc `getTexture`*(self: Object): Texture =
  if self.texture.isNil:
    self.r.texture
  else:
    self.texture

proc `name`*(self: Object): string =
  if self.n.len > 0:
    self.n
  else:
    getf(self.table, "name", self.n)
    self.n

proc `name=`*(self: Object, name: string) =
  self.n = name

proc newLayer(names: seq[string], parallax: Vec2f, zsort: int): Layer =
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
  layer.room = result
  result.layers.add(layer)

  # layers
  if jRoom.hasKey("layers"):
    for jLayer in jRoom["layers"].items():
      names.setLen(0)
      let parallax = parseParallax(jLayer["parallax"])
      let zsort = jLayer["zsort"].getInt
      if jLayer["name"].kind == JArray:
        for jName in jLayer["name"].items():
          names.add(jName.getStr())
      elif jLayer["name"].kind == JString:
        names.add(jLayer["name"].getStr)
      let layer = newLayer(names, parallax, zsort)
      layer.room = result
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
      obj.parent = if jObject.hasKey("parent"): jObject["parent"].getStr() else: ""
      obj.r = result
      if jObject.hasKey("animations"):
        obj.anims = parseObjectAnimations(jObject["animations"])
      result.layers[0].objects.add(obj)

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

proc `room=`*(self: Object, room: Room) =
  let oldRoom = self.r
  if not oldRoom.isNil:
    info fmt"Remove {self.name} from room {oldRoom.name}"
    oldRoom.layers[0].objects.del oldRoom.layers[0].objects.find(self)
  if not room.isNil:
    info fmt"Add {self.name} in room {room.name}"
    room.layers[0].objects.add self
  self.r = room

proc `room`*(self: Object): Room =
  self.r

proc play*(self: Object) =
  self.elapsedMs = 0
  self.state = asPlay
  self.frameIndex = 0

proc pause*(self: Object) =
  self.state = asPause

proc update*(self: Object, elapsedSec: float) =
  if not self.alphaTo.isNil and self.alphaTo.enabled:
    self.alphaTo.update(elapsedSec)
    
proc update*(self: var Layer, elapsedSec: float) = 
  for obj in self.objects.mitems:
    obj.update(elapsedSec)

proc update*(self: var Room, elapsedSec: float) = 
  for layer in self.layers.mitems:
    layer.update(elapsedSec)

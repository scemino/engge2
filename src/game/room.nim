import std/[json, parseutils, options, sequtils, streams, algorithm, sugar, strformat, logging, tables]
import glm
import sqnim
import ids
import ../script/vm
import ../script/squtils
import ../gfx/recti
import ../gfx/spritesheet
import ../gfx/texture
import ../gfx/color
import ../gfx/text
import ../gfx/graphics
import ../scenegraph/node
import ../scenegraph/scene
import ../scenegraph/spritenode
import ../scenegraph/textnode
import motors/motor
import objanim
import ../util/jsonutil
import eventmanager
import trigger
import resmanager
import ../polyBool/polyBool
import walkbox
import graph

const 
  GONE = 4
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
    objects*: seq[Object]
    room: Room
    node*: Node
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
  TalkingState* = object
    obj*: Object
    color*: Color
  Object* = ref object of RootObj
    n: string
    usePos*: Vec2f
    useDir*: Direction
    hotspot*: Recti
    objType*: ObjectType
    anims*: seq[ObjectAnimation]
    state: int
    alphaTo*: Motor
    rotateTo*: Motor
    moveTo*: Motor
    nodeAnim*: Motor
    walkTo*: Motor
    talking*: Motor
    table*: HSQOBJECT
    touchable*: bool
    r: Room
    spriteSheet*: SpriteSheet
    texture*: Texture
    facing*: Facing
    lockFacing: bool
    facingMap: Table[Facing, Facing]
    walkSpeed*: Vec2f
    parent*: string
    node*: Node
    sayNode*: Node
    fps*: float
    layer: Layer
    temporary*: bool
    useWalkboxes*: bool
    triggers*: Table[int, Trigger]
    volume*: float
    hiddenLayers*: seq[string]
    talkingState*: TalkingState
    talkColor*: Color
    talkOffset*: Vec2i
  Room* = ref object of RootObj
    name*: string                 ## Name of the room
    sheet*: string                ## Name of the spritesheet to use
    roomSize*: Vec2i              ## Size of the room
    fullscreen*: int32            ## Indicates if a room is a closeup room (fullscreen=1) or not (fullscreen=2), just a guess
    height*: int32                ## Height of the room (what else ?)
    layers*: seq[Layer]           ## Parallax layers of a room
    walkboxes*: seq[Walkbox]      ## Represents the areas where an actor can or cannot walk
    scalings*: seq[Scaling]       ## Defines the scaling of the actor in the room
    texture*: Texture             ## Texture used by the spritesheet
    spriteSheet*: SpriteSheet     ## Spritesheet to use when a sprtie is displayed in the room
    table*: HSQOBJECT             ## Squirrel table representing this room
    overlay*: Color               ## Color of the overlay
    scene*: Scene                 ## This is the scene representing the hierarchy of a room
    entering: bool                ## indicates whether or not an actor is entering this room
    mergedPolygon*: seq[Walkbox]
    pathFinder: PathFinder
  RoomParser = object
    input: Stream
    filename: string

# Facing
proc flip*(facing: Facing): Facing =
  case facing:
  of FACE_BACK:
    result = FACE_FRONT
  of FACE_FRONT:
    result = FACE_BACK
  of FACE_LEFT:
    result = FACE_RIGHT
  of FACE_RIGHT:
    result = FACE_LEFT

# Object
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

proc `id`*(self: Object): int =
  getf(self.table, "_id", result)

proc `room`*(self: Object): Room =
  self.r

proc layer*(self: Room, layer: int): Layer =
  for l in self.layers:
    if l.zsort == layer:
      return l

proc showLayer*(self: Object, layer: string, visible: bool) =
  if visible:
    if self.hiddenLayers.contains(layer):
      self.hiddenLayers.del self.hiddenLayers.find(layer)
  else:
    if not self.hiddenLayers.contains(layer):
      self.hiddenLayers.add(layer)
  if not self.node.isNil:
    for node in self.node.children:
      if node.name == layer:
        node.visible = visible

proc `room=`*(self: Object, room: Room) =
  let oldRoom = self.r
  if not oldRoom.isNil:
    info fmt"Remove {self.name} from room {oldRoom.name}"
    oldRoom.layer(0).objects.del oldRoom.layer(0).objects.find(self)
    room.layer(0).node.removeChild self.node
  if not room.isNil:
    info fmt"Add {self.name} in room {room.name}"
    room.layer(0).objects.add self
    room.layer(0).node.addChild self.node
  self.r = room

proc lockFacing*(self: Object, left, right, front, back: Facing) =
  self.facingMap[FACE_LEFT] = left
  self.facingMap[FACE_RIGHT] = right
  self.facingMap[FACE_FRONT] = front
  self.facingMap[FACE_BACK] = back
  self.lockFacing = true

proc unlockFacing*(self: Object) =
  self.lockFacing = false

proc resetLockFacing*(self: Object) =
  self.facingMap[FACE_LEFT] = FACE_LEFT
  self.facingMap[FACE_RIGHT] = FACE_RIGHT
  self.facingMap[FACE_FRONT] = FACE_FRONT
  self.facingMap[FACE_BACK] = FACE_BACK

proc trig*(self: Object, name: string) =
  debug fmt"Trigger object #{self.id} ({self.name}) sound '{name}'"
  var trigNum: int
  if parseInt(name, trigNum, 1) != 0:
    if self.triggers.contains(trigNum):
      self.triggers[trigNum].trig()
    else:
      warn fmt"Trigger #{trigNum} not found in object #{self.id} ({self.name})"
  else:
    gEventMgr.trig(name.substr(1))

proc getFacing(self: Object): Facing =
  if self.lockFacing:
    self.facingMap[self.facing]
  else:
    self.facing

proc suffix(self: Object): string =
  case self.getFacing():
  of FACE_BACK:
    result = "_back"
  of FACE_FRONT:
    result = "_front"
  of FACE_LEFT:
    result = "_left"
  of FACE_RIGHT:
    result = "_right"

import ../game/motors/nodeanim

proc playCore(self: Object, state: string; loop = false): bool =
  ## Plays an animation specified by the `state`. 
  for i in 0..<self.anims.len:
    let anim = self.anims[i]
    if anim.name == state:
      info fmt"playObjectState {self.name}, state={state}, id={i}, name={anim.name}, fps={anim.fps}, loop={anim.loop or loop}"
      self.nodeAnim = newNodeAnim(self, anim, self.fps, nil, loop)
      return true

proc play*(self: Object, state: string; loop = false) =
  ## Plays an animation specified by the `state`. 
  if not self.playCore(state, loop):
    discard self.playCore(state & self.suffix(), loop)

proc play*(self: Object, state: int; loop = false) =
  self.play fmt"state{state}"
  self.state = state

proc setState*(self: Object, state: int) =
  ## Changes the `state` of an object, although this can just be a internal state, 
  ## 
  ## it is typically used to change the object's image as it moves from it's current state to another.
  ## Behind the scenes, states as just simple ints. State0, State1, etc. 
  ## Symbols like `CLOSED` and `OPEN` and just pre-defined to be 0 or 1.
  ## State 0 is assumed to be the natural state of the object, which is why `OPEN` is 1 and `CLOSED` is 0 and not the other way around.
  ## This can be a little confusing at first.
  ## If the state of an object has multiple frames, then the animation is played when changing state, such has opening the clock. 
  ## `GONE` is a unique in that setting an object to `GONE` both sets its graphical state to 1, and makes it untouchable.
  ## Once an object is set to `GONE`, if you want to make it visible and touchable again, you have to set both: 
  ## 
  ## .. code-block:: Squirrel
  ## objectState(coin, HERE)
  ## objectTouchable(coin, YES)
  var graphState = if state == GONE: 1 else: state
  if self.state != state:
    self.play(graphState)
  else:
    # TODO: I should set the last frame of the animation
    discard
  self.node.visible = state != GONE
  if state == GONE:
    self.touchable = false

proc updateMotor(self: Motor, elapsedSec: float) =
  if not self.isNil and self.enabled:
    self.update(elapsedSec)

proc update*(self: Object, elapsedSec: float) =
  self.alphaTo.updateMotor(elapsedSec)
  self.rotateTo.updateMotor(elapsedSec)
  self.moveTo.updateMotor(elapsedSec)
  self.nodeAnim.updateMotor(elapsedSec)
  self.walkTo.updateMotor(elapsedSec)
  self.talking.updateMotor(elapsedSec)

proc delObject*(self: Object) =
  if not self.isNil:
    self.layer.objects.del self.layer.objects.find(self)
    self.node.parent.removeChild self.node

proc setHeadIndex*(self: Object, head: int) =
  for i in 1..6:
    self.showLayer(fmt"head{i}", i == head)

# Layer
proc newLayer(names: seq[string], parallax: Vec2f, zsort: int): Layer =
  result = Layer(names: names, parallax: parallax, zsort: zsort)

proc update*(self: Layer, elapsedSec: float) = 
  for obj in self.objects.mitems:
    obj.update(elapsedSec)

# Room
proc getScreenSize*(self: Room): Vec2i =
  case self.height:
  of 128: vec2(320'i32, 180'i32)
  of 172: vec2(428'i32, 240'i32)
  of 256: vec2(640'i32, 360'i32)
  else: vec2(self.roomSize.x, self.height)

proc roomToScreen*(self: Room, pos: Vec2f): Vec2f =
  let screenSize = self.getScreenSize()
  vec2(1280f, 720f) * (pos - cameraPos()) / vec2(screenSize.x.float32, screenSize.y.float32)

proc createObject*(self: Room; sheet = ""; frames: seq[string]): Object =
  var obj = Object(temporary: true)
  
  # create a table for this object
  sq_newtable(gVm.v)
  discard sq_getstackobj(gVm.v, -1, obj.table)
  sq_addref(gVm.v, obj.table)
  sq_pop(gVm.v, 1)

  # assign an id
  obj.table.setId(newObjId())
  info fmt"Create object with new table: {obj.name} #{obj.id}"

  obj.touchable = true
  obj.r = self
  # load spritesheet if any
  if sheet.len > 0:
    obj.spriteSheet = gResMgr.spritesheet(sheet)
    obj.texture = gResMgr.texture(obj.spriteSheet.meta.image)
  
  # create anim if any
  if frames.len > 0:
    var objAnim = ObjectAnimation.new()
    objAnim.name = "state0"
    objAnim.frames.add frames
    obj.anims.add objAnim

  # adds object to the scenegraph
  var objNode = newNode(obj.name)
  obj.node = objNode
  self.layer(0).objects.add(obj)
  self.layer(0).node.addChild obj.node
  obj.layer = self.layer(0)
  if obj.anims.len > 0:
    var ss = obj.getSpriteSheet()
    var frame = ss.frames[obj.anims[0].frames[0]]
    var spNode = newSpriteNode(obj.getTexture(), frame)
    obj.node.addChild spNode

  # play state
  obj.play(0)
  result = obj

proc createTextObject*(self: Room, fontName, text: string, align = taLeft; maxWidth = 0.0f): Object =
  var obj = Object(temporary: true)
  
  # create a table for this object
  sq_newtable(gVm.v)
  discard sq_getstackobj(gVm.v, -1, obj.table)
  sq_addref(gVm.v, obj.table)
  sq_pop(gVm.v, 1)

  # assign an id
  obj.table.setId(newObjId())
  info fmt"Create object with new table: {obj.name} #{obj.id}"

  var font = gResMgr.font(fontName)
  var text = newText(font, text, align, maxWidth, White)

  var node = newTextNode(text)
  case align:
  of taLeft:
    node.setAnchorNorm(vec2(0f, 0.5f))
  of taCenter:
    node.setAnchorNorm(vec2(0.5f, 0.5f))
  of taRight:
    node.setAnchorNorm(vec2(1f, 0.5f))
  obj.node = node
  
  self.layer(0).objects.add(obj)
  self.layer(0).node.addChild obj.node
  obj.layer = self.layer(0)
  obj

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
  result.scene = newScene()

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
      var walkbox = parseWalkbox(jWalkbox["polygon"].getStr)
      if jWalkbox.hasKey("name") and jWalkbox["name"].kind == JString:
        walkbox.name = jWalkbox["name"].getStr
      result.walkboxes.add(walkbox)

  # objects
  if jRoom.hasKey("objects"):
    for jObject in jRoom["objects"]:
      var obj = new(Object)
      obj.name = jObject["name"].getStr
      obj.usePos = vec2f(parseVec2i(jObject["usepos"].getStr))
      let useDir = jObject.getNode("usedir")
      obj.useDir = if useDir.isSome: parseUseDir(useDir.get) else: dNone
      obj.hotspot = parseRecti(jObject["hotspot"].getStr)
      obj.objType = toObjectType(jObject)
      obj.touchable = true
      obj.parent = if jObject.hasKey("parent"): jObject["parent"].getStr() else: ""
      obj.r = result
      if jObject.hasKey("animations"):
        obj.anims = parseObjectAnimations(jObject["animations"])
      var objNode = newNode(obj.name)
      objNode.pos = vec2f(parseVec2i(jObject["pos"].getStr))
      objNode.zOrder = jObject["zsort"].getInt().int32
      obj.node = objNode
      obj.layer = result.layer(0)

      result.layer(0).objects.add(obj)

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

  result.spriteSheet = gResMgr.spritesheet(result.sheet)
  result.texture = gResMgr.texture(result.spriteSheet.meta.image)
  result.mergedPolygon = merge(result.walkboxes)

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

proc objectParallaxLayer*(self: Room, obj: Object, zsort: int) =
  if obj.layer != self.layer(zsort):
    for i in 0..<self.layers.len:
      var layer = self.layers[i]
      if layer.zsort == zsort:
        # removes object from old layer
        obj.layer.objects.del obj.layer.objects.find obj
        # adds object to the new one
        layer.objects.add obj
        # update scenegraph
        layer.node.addChild obj.node
        obj.layer = layer

proc walkboxHidden*(self: Room, name: string, hidden: bool) =
  for wb in self.walkboxes.mitems:
    if wb.name == name:
      wb.visible = not hidden
      # 1 walkbox has change so update merged polygon
      self.mergedPolygon = merge(self.walkboxes)
      self.pathFinder = nil
      return

proc calculatePath*(self: Room, frm, to: Vec2f): seq[Vec2f] =
  if self.pathFinder.isNil:
    self.pathFinder = newPathFinder(self.mergedPolygon)
  self.pathFinder.calculatePath(frm, to)

proc update*(self: Room, elapsedSec: float) = 
  for layer in self.layers.mitems:
    layer.update(elapsedSec)

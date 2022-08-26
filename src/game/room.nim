import std/[json, parseutils, options, sequtils, streams, strformat, logging, tables]
import glm
import sqnim
import ids
import ../audio/audio
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
import ../scenegraph/textnode
import ../scenegraph/overlaynode
import motors/motor
import objanim
import ../util/jsonutil
import ../util/common
import eventmanager
import trigger
import resmanager
import walkbox
import graph
import verb
import light
import screen
import shaders

const 
  GONE = 4
  USE_WITH = 2
  USE_ON = 4
  USE_IN = 32
  FullscreenCloseup* = 1
  FullscreenRoom*    = 2
type
  UseFlag* = enum
    ufNone,
    ufUseWith,
    ufUseOn,
    ufUseIn,
    ufGiveTo
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
    zsort*: int32
    objects*: seq[Object]
    room: Room
    node*: Node
  Direction* = enum
    dNone   = 0
    dRight  = 1 
    dLeft   = 2
    dFront  = 4
    dBack   = 8
  ObjectType* = enum
    otNone,
    otProp,
    otSpot,
    otTrigger
  TalkingState* = object
    obj*: Object
    color*: Color
  Object* = ref object of RootObj
    n: string                     ## name of the object
    key*: string                  ## key used to identify this object by script
    usePos*: Vec2f                ## use position
    useDir*: Direction            ## use direction
    hotspot*: Recti               ## hotspot
    objType*: ObjectType          ## object type: prop, trigger, object, spot
    sheet*: string                ## Spritesheet to use when a sprite is displayed in the room: "raw" means raw texture, empty string means use room texture
    triggerActive*: bool
    nodeAnim*: Motor
    animLoop: bool
    animName*: string
    animFlags*: int
    anims*: seq[ObjectAnimation]  
    state*: int
    alphaTo*: Motor
    rotateTo*: Motor
    moveTo*: Motor
    walkTo*: Motor
    talking*: Motor
    blink*: Motor
    turnTo*: Motor
    table*: HSQOBJECT
    r: Room
    facing*: Facing
    lockFacing: bool
    facingMap: Table[Facing, Facing]
    walkSpeed*: Vec2f
    parent*: string
    node*: Node
    sayNode*: Node
    fps*: float32
    layer*: Layer
    temporary*: bool
    useWalkboxes*: bool
    triggers*: Table[int, Trigger]
    volume*: float32
    hiddenLayers*: seq[string]
    talkingState*: TalkingState
    talkColor*: Color
    talkOffset*: Vec2i
    exec*: Sentence
    animNames*: Table[string, string]
    lit*: bool
    owner*: Object
    inventory*: seq[Object]
    inventoryOffset*: int
    icons*: seq[string]
    iconFps: int
    enter*, leave*: HSQOBJECT
    sound*: SoundId
    dependentState: int
    dependentObj: Object
  Room* = ref object of RootObj
    name*: string                 ## Name of the room
    sheet*: string                ## Name of the spritesheet to use
    roomSize*: Vec2i              ## Size of the room
    fullscreen*: int32            ## Indicates if a room is a closeup room (fullscreen=1) or not (fullscreen=2), just a guess
    height*: int32                ## Height of the room (what else ?)
    layers*: seq[Layer]           ## Parallax layers of a room
    walkboxes*: seq[Walkbox]      ## Represents the areas where an actor can or cannot walk
    scalings*: seq[Scaling]       ## Defines the scaling of the actor in the room
    scaling*: Scaling             ## Defines the scaling of the actor in the room
    texture*: Texture             ## Texture used by the spritesheet
    spriteSheet*: SpriteSheet     ## Spritesheet to use when a sprtie is displayed in the room
    table*: HSQOBJECT             ## Squirrel table representing this room
    overlayNode: OverlayNode      ## Represents an overlay
    scene*: Scene                 ## This is the scene representing the hierarchy of a room
    entering: bool                ## indicates whether or not an actor is entering this room
    lights*: array[50, Light]     ## Lights of the room
    numLights*: int               ## Number of lights
    ambientLight*: Color          ## Ambient light color
    mergedPolygon*: seq[Walkbox]
    pathFinder: PathFinder
    overlayTo*: Motor
    rotateTo*: Motor
    triggers*: seq[Object]        ## Triggers currently enabled in the room
    effect*: RoomEffect
  RoomParser = object
    input: Stream
    filename: string
  Sentence* = ref object of RootObj
    verb*: VerbId
    noun1*, noun2*: Object

proc newSentence*(verbId: VerbId, noun1, noun2: Object): Sentence = 
  Sentence(verb: verbId, noun1: noun1, noun2: noun2)

proc newObject*(): Object =
  result = Object(state: -1, talkOffset: vec2(0'i32, 90'i32))
  sq_resetobject(result.table)

proc facing*(dir: Direction): Facing =
  dir.Facing

proc getUsePos*(self: Object): Vec2f =
  if self.table.getId().isActor:
    result = self.node.pos
  else:  
    result = self.node.pos +  self.usePos

proc `touchable`*(self: Object): bool =
  if self.objType == ObjectType.otNone:
    if self.state == GONE:
      result = false
    elif not self.node.isNil and not self.node.visible:
      result = false
    elif self.table.rawexists("_touchable"):
      self.table.getf("_touchable", result)
    elif self.table.rawexists("initTouchable"):
      self.table.getf("initTouchable", result)
    else:
      result = true

proc `touchable=`*(self: Object, value: bool) =
  if self.table.rawexists("_touchable"):
    self.table.setf("_touchable", value)
  else:
    self.table.newf("_touchable", value)

proc setIcon*(self: Object, fps: int, icons: seq[string]) =
  self.icons = icons
  self.iconFps = fps
  # TODO: finish set icon

proc setIcon*(self: Object, icon: string) =
  self.setIcon(0, @[icon])

proc getIcon*(self: Object): string =
  if self.icons.len > 0:
    result = self.icons[0]
  else:
    if self.table.objType == OT_NULL:
      warn "object table is null"
    else:
      self.table.getf("icon", result)
      self.icons.add result
      info fmt"object icon is {result}"

proc getFlags*(self: Object): int =
  if self.table.rawexists("flags"):
    self.table.getf("flags", result)

proc getScaling*(self: Scaling, yPos: float32): float32 =
  if self.values.len == 0:
    1.0f
  else:
    for i in 0..<self.values.len:
      let scaling = self.values[i]
      if yPos < scaling.y.float32:
        if i == 0:
          return self.values[i].scale
        else:
          let prevScaling = self.values[i - 1]
          let dY = scaling.y - prevScaling.y
          let dScale = scaling.scale - prevScaling.scale
          let p = (yPos - prevScaling.y.float32) / dY.float32
          let scale = prevScaling.scale + (p * dScale)
          return scale
    self.values[^1].scale

proc getScaling*(self: Room, yPos: float32): float32 =
  self.scaling.getScaling(yPos)

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
  if self.sheet.len == 0:
    self.r.spriteSheet
  elif self.sheet == "raw":
    # use raw texture, don't use spritesheet
    nil
  else:
    gResMgr.spritesheet(self.sheet)

proc `name`*(self: Object): string =
  if self.table.objType == OT_TABLE and rawexists(self.table, "name"):
    getf(self.table, "name", result)
  else:
    result = self.n

proc `name=`*(self: Object, name: string) =
  self.n = name

proc `id`*(self: Object): int =
  getf(self.table, "_id", result)

proc `room`*(self: Object): Room =
  self.r

proc contains*(self: Object, pos: Vec2f): bool =
  let p = pos - self.node.pos
  self.hotspot.contains(vec2i(p))

proc layer*(self: Room, layer: int32): Layer =
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
    let layer = oldRoom.layer(0)
    let index = layer.objects.find(self)
    if index != -1:
      layer.objects.del index
    layer.node.removeChild self.node
  if not room.isNil and not room.layer(0).isNil and not room.layer(0).node.isNil:
    info fmt"Add {self.name} in room {room.name}"
    room.layer(0).objects.add self
    room.layer(0).node.addChild self.node
  self.r = room

proc setRoom*(self: Object, room: Room) =
  self.room = room

proc lockFacing*(self: Object, left, right, front, back: Facing) =
  self.facingMap[FACE_LEFT] = left
  self.facingMap[FACE_RIGHT] = right
  self.facingMap[FACE_FRONT] = front
  self.facingMap[FACE_BACK] = back
  self.lockFacing = true

proc unlockFacing*(self: Object) =
  self.lockFacing = false

proc removeInventory(self: Object, obj: Object) =
  let i = self.inventory.find(obj)
  if i >= 0:
    self.inventory.del i

proc removeInventory*(self: Object) =
  if not self.owner.isNil:
    self.owner.removeInventory(self)

proc resetLockFacing*(self: Object) =
  self.facingMap[FACE_LEFT] = FACE_LEFT
  self.facingMap[FACE_RIGHT] = FACE_RIGHT
  self.facingMap[FACE_FRONT] = FACE_FRONT
  self.facingMap[FACE_BACK] = FACE_BACK

proc trig*(self: Object, name: string) =
  # debug fmt"Trigger object #{self.id} ({self.name}) sound '{name}'"
  var trigNum: int
  if parseInt(name, trigNum, 1) != 0:
    if self.triggers.contains(trigNum):
      self.triggers[trigNum].trig()
    else:
      warn fmt"Trigger #{trigNum} not found in object #{self.id} ({self.name})"
  else:
    gEventMgr.trig(name.substr(1))

proc flags*(self: Object): int =
  if self.table.rawexists("flags"):
    self.table.getf("flags", result)

proc useFlag*(self: Object): UseFlag =
  if self.flags.hasFlag(USE_WITH):
    result = ufUseWith
  elif self.flags.hasFlag(USE_ON):
    result = ufUseOn
  elif self.flags.hasFlag(USE_IN):
    result = ufUseIn
  else:
    result = ufNone

proc getFacing*(self: Object): Facing =
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
    # there is no animation with `left` suffix but use left and flip the sprite
    result = "_right"
  of FACE_RIGHT:
    result = "_right"

proc play*(self: Object, state: string, loop = false, instant = false)

proc setFacing*(self: Object, facing: Facing) =
  if self.facing != facing:
    info fmt"set facing: {facing}"
    self.facing = facing
    if not self.nodeAnim.isNil:
      self.play(self.animName, self.animLoop)

import ../game/motors/nodeanim

proc playCore(self: Object, state: string; loop = false, instant = false): bool =
  ## Plays an animation specified by the `state`. 
  for i in 0..<self.anims.len:
    let anim = self.anims[i]
    if anim.name == state:
      self.animFlags = anim.flags
      # info fmt"playObjectState {self.name}({self.key}), state={state}, id={i}, name={anim.name}, fps={anim.fps}, loop={anim.loop or loop}, instant={instant}"
      self.nodeAnim = newNodeAnim(self, anim, self.fps, nil, loop, instant)
      return true

  # if not found, clear the previous animation
  for c in self.node.children:
    if c.name == "#anim":
      c.removeAll()
      break

proc play*(self: Object, state: string; loop = false, instant = false) =
  ## Plays an animation specified by the `state`. 
  if state == "eyes_right":
    self.showLayer("eyes_front", false)
    self.showLayer("eyes_left", false)
    self.showLayer("eyes_right", true)
  elif state == "eyes_left":
    self.showLayer("eyes_front", false)
    self.showLayer("eyes_left", true)
    self.showLayer("eyes_right", false)
  elif state == "eyes_front":
    self.showLayer("eyes_front", true)
    self.showLayer("eyes_left", false)
    self.showLayer("eyes_right", false)
  else:
    self.animName = state
    self.animLoop = loop
    if not self.playCore(state, loop, instant):
      discard self.playCore(state & self.suffix(), loop, instant)

proc play*(self: Object, state: int, loop = false, instant = false) =
  self.play fmt"state{state}", loop, instant
  self.state = state

proc getState*(self: Object): int =
  self.state

proc setState*(self: Object, state: int, instant = false) =
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
  self.play(state, false, instant)
  self.state = state

proc dependentOn*(self, dependentObj: Object, state: int) =
  self.dependentState = state
  self.dependentObj = dependentObj

proc updateMotor(self: Motor, elapsedSec: float) =
  if not self.isNil and self.enabled:
    self.update(elapsedSec)

proc update*(self: Object, elapsedSec: float) =
  if not self.dependentObj.isNil:
    self.node.visible = self.dependentObj.getState() == self.dependentState
  self.alphaTo.updateMotor(elapsedSec)
  self.rotateTo.updateMotor(elapsedSec)
  self.moveTo.updateMotor(elapsedSec)
  self.nodeAnim.updateMotor(elapsedSec)
  self.walkTo.updateMotor(elapsedSec)
  self.talking.updateMotor(elapsedSec)
  self.blink.updateMotor(elapsedSec)
  self.turnTo.updateMotor(elapsedSec)

proc delObject*(self: Object) =
  if not self.isNil:
    self.layer.objects.del self.layer.objects.find(self)
    self.node.parent.removeChild self.node

# Layer
proc newLayer*(names: seq[string], parallax: Vec2f, zsort: int32): Layer =
  # info fmt"Create layer {names}, {parallax}, {zsort}"
  result = Layer(names: names, parallax: parallax, zsort: zsort)

proc update*(self: Layer, elapsedSec: float) = 
  for obj in self.objects.toSeq:
    obj.update(elapsedSec)

# Room
proc getScreenSize*(self: Room): Vec2i =
  case self.height:
  of 128: result = vec2(320'i32, 180'i32)
  of 172: result = vec2(428'i32, 240'i32)
  of 256: result = vec2(640'i32, 360'i32)
  else: result = vec2(self.roomSize.x, self.height)

proc roomToScreen*(self: Room, pos: Vec2f): Vec2f =
  let screenSize = self.getScreenSize()
  vec2(ScreenWidth, ScreenHeight) * (pos - cameraPos()) / vec2(screenSize.x.float32, screenSize.y.float32)

proc screenToRoom*(self: Room, pos: Vec2f): Vec2f =
  let screenSize = vec2f(self.getScreenSize())
  (pos * screenSize) / vec2(ScreenWidth, ScreenHeight) + cameraPos()

proc createObject*(self: Room; sheet = ""; frames: seq[string]): Object =
  var obj = newObject()
  obj.temporary = true
  
  # create a table for this object
  sq_newtable(gVm.v)
  discard sq_getstackobj(gVm.v, -1, obj.table)
  sq_addref(gVm.v, obj.table)
  sq_pop(gVm.v, 1)

  # assign an id
  obj.table.setId(newObjId())
  let name = if frames.len > 0: frames[0] else: "noname"
  obj.table.setf("name", name)
  obj.key = name
  info fmt"Create object with new table: {obj.name} #{obj.id}"

  obj.r = self
  obj.sheet = sheet
  
  # create anim if any
  if frames.len > 0:
    var objAnim = ObjectAnimation.new()
    objAnim.name = "state0"
    objAnim.frames.add frames
    obj.anims.add objAnim

  # adds object to the scenegraph
  obj.node = newNode(obj.name)
  obj.node.zOrder = 1
  self.layer(0).objects.add(obj)
  self.layer(0).node.addChild obj.node
  obj.layer = self.layer(0)
  obj.setState(0)
  result = obj

proc createTextObject*(self: Room, fontName, text: string, hAlign = thLeft, vAlign = tvCenter, maxWidth = 0.0f): Object =
  let obj = newObject()
  obj.temporary = true
  
  # create a table for this object
  sq_newtable(gVm.v)
  discard sq_getstackobj(gVm.v, -1, obj.table)
  sq_addref(gVm.v, obj.table)
  sq_pop(gVm.v, 1)

  # assign an id
  obj.table.setId(newObjId())
  info fmt"Create object with new table: {obj.name} #{obj.id}"
  obj.name = fmt"text#{obj.id}: {text}"

  let font = gResMgr.font(fontName)
  let text = newText(font, text, hAlign, vAlign, maxWidth, White)

  let node = newTextNode(text)
  var v = 0.5f
  case vAlign:
  of tvTop:
    v = 0f
  of tvCenter:
    v = 0.5f
  of tvBottom:
    v = 1f
  case hAlign:
  of thLeft:
    node.setAnchorNorm(vec2(0f, v))
  of thCenter:
    node.setAnchorNorm(vec2(0.5f, v))
  of thRight:
    node.setAnchorNorm(vec2(1f, v))
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
  case node.kind:
  of JInt, JFloat:
    result = vec2(node.getFloat.float32, 1f)
  of JString:
    let s = node.getStr
    var x, y: float
    let o = parseFloat(s, x, 1)
    discard parseFloat(s, y, 2 + o)
    result = vec2(x.float32, y.float32)
  else:
    error fmt"parseParallax expected a float, int or string, not a {node.kind}"

proc getNode(node: JsonNode, key: string): Option[JsonNode] =
  if node.hasKey(key): some(node[key]) else: none(JsonNode)

proc parseRoom(self: var RoomParser, table: HSQOBJECT): Room =
  let jRoom = parseJson(self.input, self.filename)
  let name = jRoom["name"].getStr
  let sheet = jRoom["sheet"].getStr

  let roomSize = parseVec2i(jRoom["roomsize"].getStr)
  let height = if jRoom.hasKey "height": jRoom["height"].getInt() else: roomSize.y
  let fullscreen = if jRoom.hasKey "fullscreen": jRoom["fullscreen"].getInt else: 0

  new(result)
  result.table = table
  result.name = name
  result.sheet = sheet
  result.height = height.int32
  result.roomSize =  roomSize
  result.fullscreen = fullscreen.int32
  result.scene = newScene()
  result.overlayNode = newOverlayNode()
  result.scene.addChild result.overlayNode

  # backgrounds
  var backNames: seq[string]
  if jRoom["background"].kind == JString:
    backNames.add(jRoom["background"].getStr)
  else:
    backNames.add(jRoom["background"].items().toSeq.mapIt(it.getStr).toSeq)
  let layer = newLayer(backNames, vec2(1f, 1f), 0)
  layer.room = result
  result.layers.add(layer)

  # layers
  var names: seq[string]
  if jRoom.hasKey("layers"):
    for jLayer in jRoom["layers"].items():
      names.setLen(0)
      let parallax = parseParallax(jLayer["parallax"])
      let zsort = jLayer["zsort"].getInt.int32
      if jLayer["name"].kind == JArray:
        for jName in jLayer["name"].items():
          names.add(jName.getStr())
      elif jLayer["name"].kind == JString:
        names.add(jLayer["name"].getStr)
      let layer = newLayer(names, parallax, zsort)
      layer.room = result
      result.layers.add(layer)

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
      var obj = Object(state: -1)
      obj.key = jObject["name"].getStr
      obj.usePos = vec2f(parseVec2i(jObject["usepos"].getStr))
      let useDir = jObject.getNode("usedir")
      obj.useDir = if useDir.isSome: parseUseDir(useDir.get) else: dNone
      obj.hotspot = parseRecti(jObject["hotspot"].getStr)
      obj.objType = toObjectType(jObject)
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
    result.scaling = result.scalings[0]

  result.spriteSheet = gResMgr.spritesheet(result.sheet)
  result.texture = gResMgr.texture(result.spriteSheet.meta.image)
  result.mergedPolygon = merge(result.walkboxes)

  # Fix room size (why ?)
  var width = 0'i32
  for name in backNames:
    width += result.spriteSheet.frame(name).sourceSize.x
  result.roomSize.x = width
  # info fmt"roomSize={result.roomSize}"

proc parseRoom*(table: HSQOBJECT, s: Stream, filename: string = ""): Room =
  ## Parses from a stream `s` into a `Room`. `filename` is only needed
  ## for nice error messages.
  ## This closes the stream `s` after it's done.
  var p: RoomParser
  p.open(s, filename)
  try:
    result = p.parseRoom(table)
  finally:
    p.close()

proc parseRoom*(table: HSQOBJECT, buffer: string): Room =
  result = parseRoom(table, newStringStream(buffer), "input")

proc objectParallaxLayer*(self: Room, obj: Object, zsort: int32) =
  let layer = self.layer(zsort)
  if obj.layer != layer:
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
  self.overlayTo.updateMotor(elapsedSec)
  self.rotateTo.updateMotor(elapsedSec)
  for layer in self.layers:
    layer.update(elapsedSec)

proc createLight*(self: Room, color: Color, pos: Vec2i): Light = 
  result = newLight()
  self.lights[self.numLights] = result
  self.numLights += 1
  result.color = color
  result.pos = pos

proc `overlay=`*(self: Room, color: Color) =
  self.overlayNode.ovlColor = color

proc `overlay`*(self: Room): Color =
  self.overlayNode.ovlColor
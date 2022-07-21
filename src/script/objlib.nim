import std/strformat, logging
import std/strutils
import sqnim
import glm
import squtils
import vm
import ../game/engine
import ../game/ids
import ../game/room
import ../game/actor
import ../game/verb
import ../scenegraph/hud
import ../game/motors/motor
import ../game/motors/alphato
import ../game/motors/rotateto
import ../game/motors/moveto
import ../game/motors/offsetto
import ../game/motors/scaleto
import ../util/utils
import ../util/easing
import ../gfx/color
import ../gfx/recti
import ../gfx/text
import ../scenegraph/node

proc createObject(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Creates a new, room local object using sheet as the sprite sheet and image as the image name.
  ## This object is deleted when the room exits.
  ## If sheet parameter not provided, use room's sprite sheet instead.
  ## If image is an array, then use that as a sequence of frames for animation.
  ## Objects created at runtime can be passed to all the object commands.
  ## They do not have verbs or local variables by default, but these can be added when the object is created so it can be used in the construction of sentences. 
  let numArgs = sq_gettop(v)
  var sheet: string
  var frames: seq[string]
  var framesIndex = 2
  
  # get sheet parameter if any
  if numArgs == 3:
    if SQ_FAILED(get(v, 2, sheet)):
      return sq_throwerror(v, "failed to get sheet")
    framesIndex = 3
  
  # get frames parameter if any
  if numArgs >= 2:
    case sq_gettype(v, framesIndex):
    of OT_STRING:
      var frame: string
      discard get(v, framesIndex, frame)
      frames.add frame
    of OT_ARRAY:
      discard getarray(v, framesIndex, frames)
    else:
      return sq_throwerror(v, "Invalid parameter 2: expecting a string or an array")

  info fmt"Create object: {sheet}, {frames}"
  var obj = gEngine.room.createObject(sheet, frames)
  push(v, obj.table)
  1

proc createTextObject(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Creates a text object of the given size.
  ## TextObjects can be passed to all the object commands, but like objects created with createObject they don't have verbs or local variables by default.
  ## If alignment specified, it should take the form of: verticalAlign| horizonalAlign [| horiztonalWidth ].
  ## Valid values for verticalAlign are ALIGN_TOP|ALIGN_BOTTOM. Valid values for horizonalAlign are ALIGN_LEFT|ALIGN_CENTER|ALIGN_RIGHT.
  ## If the optional horiztonalWidth parameter is present, it will wrap the text to that width. 
  var fontName: string
  if SQ_FAILED(get(v, 2, fontName)):
    return sq_throwerror(v, "failed to get fontName")
  var text: string
  if SQ_FAILED(get(v, 3, text)):
    return sq_throwerror(v, "failed to get text")
  var thAlign = thCenter
  var tvAlign = tvCenter
  var maxWidth = 0.0f
  if sq_gettop(v) == 4:
    var align: int
    if SQ_FAILED(get(v, 4, align)):
      return sq_throwerror(v, "failed to get align")
    let hAlign = align and 0x0000000070000000
    let vAlign = align and 0xFFFFFFFFA1000000
    maxWidth = (align and 0x00000000000FFFFF).float
    case hAlign:
    of 0x0000000010000000:
      thAlign = thLeft
    of 0x0000000020000000:
      thAlign = thCenter
    of 0x0000000040000000:
      thAlign = thRight
    else:
      return sq_throwerror(v, "failed to get halign")
    case vAlign:
    of 0xFFFFFFFF80000000:
      tvAlign = tvTop
    of 0x0000000001000000:
      tvAlign = tvBottom
    else:
      tvAlign = tvCenter
  info fmt"Create text {thAlign}, {tvAlign}, max={maxWidth}, text={text}"
  let obj = gEngine.room.createTextObject(fontName, text, thAlign, tvAlign, maxWidth)
  push(v, obj.table)
  1

proc deleteObject(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Deletes object permanently from the game. 
  ## 
  ## .. code-block:: Squirrel
  ## local drip = createObject("drip")
  ## local time = 1.5
  ## objectAt(drip, 432, 125)
  ## objectOffsetTo(drip, 0, -103, time, SLOW_EASE_IN)
  ## breaktime(time)
  ## playObjectSound(randomfrom(soundDrip1, soundDrip2, soundDrip3), radioStudioBucket)
  ## deleteObject(drip)
  var obj = obj(v, 2)
  obj.delObject()

proc findObjectAt(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns the object that is at the specified coordinates.
  ## If there is no object at those coordinates, it returns NULL.
  ## Used for determining what the player is clicking on now (e.g. for the phone). 
  ## 
  ## .. code-block:: Squirrel
  ## local button = findObjectAt(x,y)
  ## if (button == null)
  ##     return NO
  ## if (objectState(button) == OFF) {
  ##     if (button == Phone.phoneReceiver) {    ... }
  ## }
  var x, y: int
  if SQ_FAILED(get(v, 2, x)):
    return sq_throwerror(v, "failed to get x")
  if SQ_FAILED(get(v, 3, y)):
    return sq_throwerror(v, "failed to get y")
  let obj = gEngine.findObjAt(vec2(x.float32,y.float32))
  if obj.isNil:
    sq_pushnull(v)
  else:
    push(v, obj.table)
  1

proc isInventoryOnScreen(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  if obj.owner.isNil or obj.owner != gEngine.actor:
    info fmt"Is '{obj.name}({obj.key})' in inventory: no"
    push(v, false)
    result = 1
  else:
    let offset = obj.owner.inventoryOffset
    let index = obj.owner.inventory.find obj
    let res = index >= offset * 4 and index < (offset * 4 + 8)
    info fmt"Is '{obj.name}({obj.key})' in inventory: {res}"
    push(v, res)
    result = 1

proc isObject(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns true if the object is actually an object and not something else. 
  ## 
  ## .. code-block:: Squirrel
  ## if (isObject(obj) && objectValidUsePos(obj) && objectTouchable(obj)) {
  var obj: HSQOBJECT
  discard sq_getstackobj(v, 2, obj)
  var isObj = obj.objType == OT_TABLE and obj.getId().isObject()
  if not isObj and obj.objType == OT_TABLE:
    var name: string
    getf(obj, "name", name)
    info fmt"Object {name} {obj.getId()} is not an object"
  push(v, isObj)
  1

proc jiggleInventory(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  var enabled: bool
  if SQ_FAILED(get(v, 3, enabled)):
    return sq_throwerror(v, "failed to get enabled")
  warn "jiggleInventory not implemented"
  0

proc jiggleObject(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Rotate the object around its origin back and forth by the specified amount of pixels.
  ## See also:
  ## - `shakeObject`
  ## - `stopObjectMotors`
  ## 
  ## .. code-block:: Squirrel
  ## jiggleObject(pigeonVan, 0.25)
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  var amount: float
  if SQ_FAILED(get(v, 3, amount)):
    return sq_throwerror(v, "failed to get amount")
  warn "jiggleObject not implemented"
  0
  
proc loopObjectState(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Works exactly the same as playObjectState, but plays the animation as a continuous loop, playing the specified animation. 
  ## 
  ## .. code-block:: Squirrel
  ## loopObjectState(aStreetFire, 0)
  ## loopObjectState(flies, 3)
  let obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  if sq_gettype(v, 3) == OT_INTEGER:
    var index: int
    if SQ_FAILED(get(v, 3, index)):
      return sq_throwerror(v, "failed to get state")
    obj.play(index, true)
  elif sq_gettype(v, 3) == OT_STRING:
    var state: string
    if SQ_FAILED(get(v, 3, state)):
      return sq_throwerror(v, "failed to get state (string)")
    obj.play(state, true)
  else:
    return sq_throwerror(v, "failed to get state")
  0

proc objectAt(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Places the specified object at the given x and y coordinates in the current room.
  ## 
  ## .. code-block:: Squirrel
  ## objectAt(text, 160,90)
  ## objectAt(obj, leftMargin, topLinePos)
  let obj = obj(v, 2)
  if obj.isNil:
    result = sq_throwerror(v, "failed to get object")
  elif sq_gettop(v) == 3:
    let spot = obj(v, 3)
    if spot.isNil:
      result = sq_throwerror(v, "failed to get spot")
    else:
      obj.node.pos = spot.node.pos
      result = 0
  elif sq_gettop(v) == 4:
    var x, y: SQInteger
    if SQ_FAILED(sq_getinteger(v, 3, x)):
      return sq_throwerror(v, "failed to get x")
    if SQ_FAILED(sq_getinteger(v, 4, y)):
      return sq_throwerror(v, "failed to get y")
    obj.node.pos = vec2(x.float32, y.float32)
    result = 0
  else:
    result = sq_throwerror(v, "invalid number of arguments")

proc objectAlpha(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets an object's alpha (transparency) in the range of 0.0 to 1.0.
  ## Setting an object's color will set it's alpha back to 1.0, ie completely opaque. 
  ## 
  ## .. code-block:: Squirrel
  ## objectAlpha(cloud, 0.5)
  let obj = obj(v, 2)
  if not obj.isNil:
    var alpha = 0.0f
    if SQ_FAILED(sq_getfloat(v, 3, alpha)):
      return sq_throwerror(v, "failed to get alpha")
    if not obj.alphaTo.isNil:
      obj.alphaTo.disable()
    obj.node.alpha = alpha
  0

proc objectAlphaTo(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Changes an object's alpha from its current state to the specified alpha over the time period specified by time.
  ## 
  ## If an interpolationMethod is used, the change will follow the rules of the easing method, e.g. LINEAR, EASE_INOUT.
  ## See also stopObjectMotors. 
  let obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  var alpha = 0.0
  if SQ_FAILED(get(v, 3, alpha)):
    return sq_throwerror(v, "failed to get alpha")
  alpha = clamp(alpha, 0.0, 1.0);
  var t = 0.0
  if SQ_FAILED(get(v, 4, t)):
    return sq_throwerror(v, "failed to get time")
  var interpolation = 0
  if sq_gettop(v) >= 5 and SQ_FAILED(get(v, 5, interpolation)):
    interpolation = 0
  obj.alphaTo = newAlphaTo(t, obj, alpha, interpolation)
  0

proc objectBumperCycle(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  var enabled = 0
  if SQ_FAILED(get(v, 3, enabled)):
    return sq_throwerror(v, "failed to get enabled")
  # TODO: objectBumperCycle
  0

proc objectCenter(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  let pos = obj.node.pos + obj.usePos
  push(v, pos)
  1

proc objectColor(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets an object's color. The color is an int in the form of 0xRRGGBB 
  ## 
  ## .. code-block:: Squirrel
  ## objectColor(warningSign, 0x808000)
  var obj = obj(v, 2)
  if not obj.isNil:
    var color = 0
    if SQ_FAILED(get(v, 3, color)):
      return sq_throwerror(v, "failed to get color")
    obj.node.color = rgba(color)
  0

proc objectDependentOn(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let child = obj(v, 2)
  if child.isNil:
    return sq_throwerror(v, "failed to get child object")
  let parent = obj(v, 3)
  if parent.isNil:
    return sq_throwerror(v, "failed to get parent object")
  var state = 0
  if SQ_FAILED(get(v, 4, state)):
    return sq_throwerror(v, "failed to get state")
  warn "objectDependentOn not implemented"
  0

proc objectFPS(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets how many frames per second (fpsRate) the object will animate at. 
  ## 
  ## .. code-block:: Squirrel
  ## objectFPS(pigeon1, 15)
  var obj = obj(v, 2)
  if not obj.isNil:
    var fps = 0.0
    if SQ_FAILED(get(v, 3, fps)):
      return sq_throwerror(v, "failed to get fps")
    obj.fps = fps
  0

proc objectHidden(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets if an object is hidden or not. If the object is hidden, it is no longer displayed or touchable. 
  ## 
  ## .. code-block:: Squirrel
  ## objectHidden(oldRags, YES)
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object or actor")
  else:
    var hidden = 0
    discard get(v, 3, hidden)
    info fmt"Sets object visible {obj.name} to {hidden == 0}"
    obj.node.visible = hidden == 0
  0

proc objectHotspot(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets the touchable area of an actor or object.
  ## This is a rectangle enclosed by the specified coordinates.
  ## We also use this on the postalworker to enlarge his touchable area to make it easier to click on him while he's sorting mail. 
  ## 
  ## .. code-block:: Squirrel
  ## objectHotspot(willie, 14, 0, 14, 62)         // Willie standing up
  ## objectHotspot(willie, -28, 0, 28, 50)        // Willie lying down drunk
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object or actor")
  if sq_gettop(v) == 2:
    let pos = obj.node.absolutePosition()
    push(v, rectFromPositionSize(obj.hotspot.pos + vec2(pos.x.int32, pos.y.int32), obj.hotspot.size))
    result = 1
  else:
    var left = 0'i32
    var top = 0'i32
    var right = 0'i32
    var bottom = 0'i32
    if SQ_FAILED(get(v, 3, left)):
      return sq_throwerror(v, "failed to get left")
    if SQ_FAILED(get(v, 4, top)):
      return sq_throwerror(v, "failed to get top")
    if SQ_FAILED(get(v, 5, right)):
      return sq_throwerror(v, "failed to get right")
    if SQ_FAILED(get(v, 6, bottom)):
      return sq_throwerror(v, "failed to get bottom")
    obj.hotspot = rect(left, top, right-left, bottom-top)
    result = 0

proc objectIcon(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Used for inventory object, it changes the object's icon to be the new one specified.
  ## 
  ## .. code-block:: Squirrel
  ## objectIcon(obj, "glowing_spell_book")
  ## objectIcon(obj, "spell_book")
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  case sq_gettype(v, 3):
  of OT_STRING:
    var icon: string
    if SQ_FAILED(get(v, 3, icon)):
      return sq_throwerror(v, "failed to get icon")
    obj.setIcon(icon)
    return 0
  of OT_ARRAY:
    var icon: string
    var icons: seq[string]
    var fps: int
    sq_push(v, 3)
    sq_pushnull(v) # null iterator
    if SQ_SUCCEEDED(sq_next(v, -2)):
      discard get(v, -1, fps)
      sq_pop(v, 2)
    while SQ_SUCCEEDED(sq_next(v, -2)):
      discard get(v, -1, icon)
      icons.add(icon)
      sq_pop(v, 2)
    sq_pop(v, 2)  # pops the null iterator and object
    obj.setIcon(fps, icons)
    return 0
  else:
    return sq_throwerror(v, "invalid argument type")

proc objectLit(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Specifies whether the object is affected by lighting elements.
  ## Note: this is currently used for actor objects, but can also be used for room objects.
  ## Lighting background flat art would be hard and probably look odd. 
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object or actor")
  var lit = false
  if SQ_FAILED(get(v, 3, lit)):
    return sq_throwerror(v, "failed to get lit")
  obj.lit = lit
  0

proc objectMoveTo(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Moves the object to the specified location over the time period specified.
  ## 
  ## If an interpolation method is used for the transition, it will use that.
  ## Unlike `objectOffsetTo`, `objectMoveTo` moves the item to a x, y on the screen, not relative to the object's starting position.
  ## If you want to move the object back again, you need to store where the object started.
  ## 
  ## .. code-block:: Squirrel
  ## objectMoveTo(this, 10, 20, 2.0)
  ## 
  ## See also:
  ## - `stopObjectMotors method <#stopObjectMotors.e>`_
  ## - `objectOffsetTo method <#objectOffsetTo.e>`_
  var obj = obj(v, 2)
  if not obj.isNil:
    var x = 0
    var y = 0
    if SQ_FAILED(get(v, 3, x)):
      return sq_throwerror(v, "failed to get x")
    if SQ_FAILED(get(v, 4, y)):
      return sq_throwerror(v, "failed to get y")
    var duration = 0.0
    if SQ_FAILED(get(v, 5, duration)):
      return sq_throwerror(v, "failed to get duration")
    var interpolation = 0
    if sq_gettop(v) >= 6 and SQ_FAILED(get(v, 6, interpolation)):
      interpolation = 0
    var destPos = vec2(x.float32, y.float32)
    obj.moveTo = newMoveTo(duration, obj, destPos, interpolation)
  0

proc objectOffset(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Instantly offsets the object (image, use position, hotspot) with respect to the origin of the object.
  ## 
  ## .. code-block:: Squirrel
  ## objectOffset(coroner, 0, 0)
  ## objectOffset(SewerManhole.sewerManholeDime, 0, 96)
  var obj = obj(v, 2)
  if not obj.isNil:
    var x = 0
    var y = 0
    if SQ_FAILED(get(v, 3, x)):
      return sq_throwerror(v, "failed to get x")
    if SQ_FAILED(get(v, 4, y)):
      return sq_throwerror(v, "failed to get x")
    if not obj.moveTo.isNil:
      obj.moveTo.disable()
    obj.node.offset = vec2(x.float32, y.float32)
  0

proc objectOffsetTo(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Changes the object's offset (image, use position, hotspot) with respect to the origin of the object.
  ## 
  ## Does this over the time period specified.
  ## If an interpolation method is used for the transition, it will use that.
  ## Useful for when you want to be able to move an object to a new position then move it back (you'd move it back to 0).
  ## 
  ## .. code-block:: Squirrel
  ## objectOffsetTo(actor, -40, 0, 0.5)
  ## objectOffsetTo(rat, random(-1, 1), random(-1, 1), 0.2, LINEAR)
  ## objectOffsetTo(ladder, ladder.position*ladder.offset, 0, 1, EASE_INOUT)
  ## 
  ## See also:
  ## - `stopObjectMotors method <#stopObjectMotors.e>`_
  ## - `objectMoveTo method <#objectMoveTo.e>`_
  let obj = obj(v, 2)
  if not obj.isNil:
    var x = 0
    var y = 0
    if SQ_FAILED(get(v, 3, x)):
      return sq_throwerror(v, "failed to get x")
    if SQ_FAILED(get(v, 4, y)):
      return sq_throwerror(v, "failed to get y")
    var duration = 0.0
    if SQ_FAILED(get(v, 5, duration)):
      return sq_throwerror(v, "failed to get duration")
    var interpolation = 0.SQInteger
    if sq_gettop(v) >= 6 and SQ_FAILED(sq_getinteger(v, 6, interpolation)):
      interpolation = 0
    var destPos = vec2(x.float32, y.float32)
    obj.moveTo = newOffsetTo(duration, obj, destPos, interpolation)
  0

proc objectOwner(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns the actor who owns the specified object/inventory item.
  ## If there is no owner, returns false. 
  ## 
  ## .. code-block:: Squirrel
  ## objectOwner(dime) == currentActor
  ## !objectOwner(countyMap1)
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  if obj.owner.isNil:
    sq_pushnull(v)
  else:
    sq_pushobject(v, obj.owner.table)
  1

proc objectParallaxLayer(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Changes the object's layer.
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  var layer = 0'i32
  if SQ_FAILED(get(v, 3, layer)):
    return sq_throwerror(v, "failed to get parallax layer")
  gEngine.room.objectParallaxLayer(obj, layer)
  0

proc objectParent(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get child")
  var parent = obj(v, 3)
  if parent.isNil:
    return sq_throwerror(v, "failed to get parent")
  obj.parent = parent.key
  parent.node.addChild obj.node
  0

proc objectPosX(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns the x-coordinate of the given object or actor.
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  push(v, obj.node.absolutePosition().x + obj.usePos.x + obj.hotspot.x.float32 + obj.hotspot.w.float32 / 2.0f)
  1

proc objectPosY(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns the y-coordinate of the given object or actor.
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  push(v, obj.node.absolutePosition().y + obj.usePos.y + obj.hotspot.y.float32 + obj.hotspot.h.float32 / 2.0f)
  1

proc objectRenderOffset(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets the rendering offset of the actor to x and y.
  ## 
  ## A rendering offset of 0,0 would cause them to be rendered from the middle of their image.
  ## Actor's are typically adjusted so they are rendered from the middle of the bottom of their feet.
  ## To maintain sanity, it is best if all actors have the same image size and are all adjust the same, but this is not a requirement. 
  let obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  var x, y: SQInteger
  if SQ_FAILED(sq_getinteger(v, 3, x)):
    return sq_throwerror(v, "failed to get x")
  if SQ_FAILED(sq_getinteger(v, 4, y)):
    return sq_throwerror(v, "failed to get y")
  obj.node.renderOffset = vec2f(x.float32, y.float32)
  0

proc objectRoom(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns the room of a given object or actor.
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  if obj.room.isNil:
    sq_pushnull(v)
  else:
    push(v, obj.room.table)
  1

proc objectRotate(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets the rotation of object to the specified amount instantly.
  ## 
  ## .. code-block:: Squirrel
  ## objectRotate(pigeonVanBackWheel, 0)
  var obj = obj(v, 2)
  if not obj.isNil:
    var rotation = 0.0f
    if SQ_FAILED(sq_getfloat(v, 3, rotation)):
      return sq_throwerror(v, "failed to get rotation")
    if not obj.rotateTo.isNil:
      obj.rotateTo.disable()
    obj.node.rotation = -rotation
  0

proc objectRotateTo(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Rotates the object from its current rotation to the desired rotation over duration time period.
  ## The interpolationMethod specifies how the animation is played.
  ## if `LOOPING` is used, it will continue to rotate as long as the rotation parameter is 360 or -360.
  ## 
  ## .. code-block:: Squirrel
  ## objectRotateTo(bridgeGrateTree, 45, 3.7, SLOW_EASE_IN)
  ## objectRotateTo(AStreet.aStreetPhoneBook, 6, 2.0, SWING)
  ## objectRotateTo(firefly, direction, 12, LOOPING)
  var obj = obj(v, 2)
  if not obj.isNil:
    var rotation = 0.0
    if SQ_FAILED(get(v, 3, rotation)):
      return sq_throwerror(v, "failed to get rotation")
    var duration = 0.0
    if SQ_FAILED(get(v, 4, duration)):
      return sq_throwerror(v, "failed to get duration")
    var interpolation = 0
    if sq_gettop(v) >= 5 and SQ_FAILED(get(v, 5, interpolation)):
      interpolation = 0
    obj.rotateTo = newRotateTo(duration, obj.node, -rotation, interpolation)
  0

proc objectScale(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets how scaled the object's image will appear on screen. 1 is no scaling.
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  var scale = 0.0
  if SQ_FAILED(get(v, 3, scale)):
    return sq_throwerror(v, "failed to get scale")
  obj.node.scale = vec2(scale.float32, scale.float32)
  0

proc objectScaleTo(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var obj = obj(v, 2)
  if not obj.isNil:
    var scale = 0.0
    if SQ_FAILED(get(v, 3, scale)):
      return sq_throwerror(v, "failed to get scale")
    var duration = 0.0
    if SQ_FAILED(get(v, 4, duration)):
      return sq_throwerror(v, "failed to get duration")
    var interpolation = 0
    if sq_gettop(v) >= 5 and SQ_FAILED(get(v, 5, interpolation)):
      interpolation = 0
    obj.rotateTo = newScaleTo(duration, obj.node, scale, interpolation)
  0

proc objectScreenSpace(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets the object in the screen space.
  ## It means that its position is relative to the screen, not to the room.
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  gEngine.screen.addChild obj.node

proc objectShader(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  error "TODO: objectShader: not implemented"
  0

proc objectState(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Changes the state of an object, although this can just be a internal state, 
  ## 
  ## it is typically used to change the object's image as it moves from it's current state to another.
  ## Behind the scenes, states as just simple ints. State0, State1, etc. 
  ## Symbols like CLOSED and OPEN and just pre-defined to be 0 or 1.
  ## State 0 is assumed to be the natural state of the object, which is why OPEN is 1 and CLOSED is 0 and not the other way around.
  ## This can be a little confusing at first.
  ## If the state of an object has multiple frames, then the animation is played when changing state, such has opening the clock. 
  ## GONE is a unique in that setting an object to GONE both sets its graphical state to 1, and makes it untouchable. Once an object is set to GONE, if you want to make it visible and touchable again, you have to set both: 
  ## 
  ## .. code-block:: Squirrel
  ## objectState(coin, HERE)
  ## objectTouchable(coin, YES)
  let obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  let nArgs = sq_gettop(v)
  if nArgs == 2:
    push(v, obj.getState())
    return 1
  if nArgs != 3:
    return sq_throwerror(v, "invalid number of arguments")
  var state: int
  if SQ_FAILED(get(v, 3, state)):
    return sq_throwerror(v, "failed to get state")
  obj.setState(state)
  0

proc objectTouchable(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Gets or sets if an object is player touchable. 
  let obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  let nArgs = sq_gettop(v)
  if nArgs == 2:
    push(v, obj.touchable)
    result = 1
  elif nArgs == 3:
    var touchable: SQInteger
    if SQ_FAILED(sq_getinteger(v, 3, touchable)):
      return sq_throwerror(v, "failed to get touchable")
    obj.touchable = touchable != 0
    result = 0

proc objectSort(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ##  Sets the zsort order of an object, essentially the order in which an object is drawn on the screen.
  ## A sort order of 0 is the bottom of the screen.
  ## Actors typically have a sort order of their Y position.
  ## 
  ## .. code-block:: Squirrel
  ## objectSort(censorBox, 0)   // Will be on top of everything.
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  var zsort: int
  if SQ_FAILED(get(v, 3, zsort)):
    return sq_throwerror(v, "failed to get zsort")
  obj.node.zOrder = zsort.int32
  0

proc objectUsePos(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets the location an actor will stand at when interacting with this object.
  ## Directions are: FACE_FRONT, FACE_BACK, FACE_LEFT, FACE_RIGHT 
  ## 
  ## .. code-block:: Squirrel
  ## objectUsePos(popcornObject, -13, 0, FACE_RIGHT)
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  var x, y, dir: int
  if SQ_FAILED(get(v, 3, x)):
    return sq_throwerror(v, "failed to get x")
  if SQ_FAILED(get(v, 4, y)):
    return sq_throwerror(v, "failed to get y")
  if SQ_FAILED(get(v, 5, dir)):
    return sq_throwerror(v, "failed to get direction")
  obj.usePos = vec2f(x.float32, y.float32)
  obj.useDir = dir.Direction
  0

proc objectUsePosX(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns the x of the object's use position. 
  ## 
  ## .. code-block:: Squirrel
  ## objectUsePosX(dimeLoc)
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  push(v, obj.usePos.x)
  1

proc objectUsePosY(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns the y of the object's use position. 
  ## 
  ## .. code-block:: Squirrel
  ## objectUsePosY(dimeLoc)
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  push(v, obj.usePos.y)
  1

proc objectValidUsePos(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns true if the object's use position has been set (ie is not 0,0). 
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  let pos = vec2i(obj.usePos)
  push(v, pos != vec2i(0,0))
  1

proc objectValidVerb(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns true if this object has a verb function for the specified verb.
  ## Mostly used for testing when trying to check interactions.
  ## Verb options are: VERB_WALKTO, VERB_LOOKAT, VERB_PICKUP, VERB_OPEN, VERB_CLOSE, VERB_PUSH, VERB_PULL, VERB_TALKTO.
  ## Cannot use DEFAULT_VERB because that is not a real verb to the system. 
  ## 
  ## .. code-block:: Squirrel
  ## if (objectValidVerb(obj, VERB_PICKUP)) {
  ##    logAction("PickUp", obj)
  ##    pushSentence(VERB_PICKUP, obj)
  ##    tries = 0
  ##}
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object or actor")
  var verb: int
  if SQ_FAILED(get(v, 3, verb)):
    return sq_throwerror(v, "failed to get verb")
  
  let verbId = verb.VerbId
  if not gEngine.actor.isNil:
    for vb in gEngine.hud.actorSlot(gEngine.actor).verbs:
      if vb.id == verbId:
        if obj.table.rawexists(vb.fun):
          push(v, true)
          return 1
  push(v, false)
  1

proc pickupObject(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Picks up an object and adds it to the selected actor's inventory.
  ## The object that appears in the room is not the object you pick up, this is due to the code often needing to be very different when it's held in your inventory, plus inventory objects need icons. 
  ## 
  ## .. code-block:: Squirrel
  ## pickupObject(Dime)
  var actor: Object
  let obj = obj(v, 2)
  if obj.isNil:
    var o: HSQOBJECT
    discard sq_getstackobj(v, 2, o)
    var name: string
    o.getf("name", name)
    return sq_throwerror(v, fmt"failed to get object {o.objType.toHex}, {name}".cstring)
  if sq_gettop(v) >= 3:
    actor = actor(v, 3)
    if actor.isNil:
      return sq_throwerror(v, "failed to get actor")
  if actor.isNil:
    actor = gEngine.actor
  actor.pickupObject(obj)
  gEngine.hud.updateInventory()
  0

proc pickupReplacementObject(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  warn "pickupReplacementObject not implemented"
  0

proc playObjectState(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## The only difference between objectState and playObjectState is if they are called during the enter code.
  ## objectState will set the image to the last frame of the state's animation, where as, playObjectState will play the full animation. 
  ## 
  ## .. code-block:: Squirrel
  ## playObjectState(Mansion.windowShutters, OPEN)
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  if sq_gettype(v, 3) == OT_INTEGER:
    var index: SQInteger
    if SQ_FAILED(sq_getinteger(v, 3, index)):
      return sq_throwerror(v, "failed to get state")
    obj.play(index)
  elif sq_gettype(v, 3) == OT_STRING:
    var sqState: SQString
    if SQ_FAILED(sq_getstring(v, 3, sqState)):
      return sq_throwerror(v, "failed to get state")
    obj.play($sqState)
  else:
    return sq_throwerror(v, "failed to get state")
  0

proc popInventory(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  warn "popInventory not implemented"
  0

proc removeInventory(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Removes an object from the current actor's inventory.
  ## If the object is not in the current actor's inventory, the command silently fails.
  let obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  obj.removeInventory()
  0

proc setDefaultObject(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Globally sets a default object.
  ## When the player executes the sentence open painting and the painting object has no verbOpen function defined,
  ## it will call the default object's verbOpen as a fallback, allowing for common failure phrase like "I can't open that.".
  ## The default object can be changed at anytime, so different selectable characters can have different default responses. 
  if gEngine.defaultObj.objType != OT_NULL:
    discard sq_release(gVm.v, gEngine.defaultObj)
  if SQ_FAILED(sq_getstackobj(v, 2, gEngine.defaultObj)):
    return sq_throwerror(v, "failed to get default object")
  sq_addref(gVm.v, gEngine.defaultObj)
  0

proc shakeObject(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  var amount: float
  if SQ_FAILED(get(v, 3, amount)):
    return sq_throwerror(v, "failed to get amount")
  warn "shakeObject not implemented"
  0

proc stopObjectMotors(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  warn "stopObjectMotors not implemented"
  0

proc register_objlib*(v: HSQUIRRELVM) =
  ## Registers the game object library
  ## 
  ## It adds all the object functions in the given Squirrel virtual machine.
  v.regGblFun(createObject, "createObject")
  v.regGblFun(createTextObject, "createTextObject")
  v.regGblFun(deleteObject, "deleteObject")
  v.regGblFun(findObjectAt, "findObjectAt")
  v.regGblFun(isInventoryOnScreen, "isInventoryOnScreen")
  v.regGblFun(isObject, "is_object")
  v.regGblFun(isObject, "isObject")
  v.regGblFun(jiggleInventory, "jiggleInventory")
  v.regGblFun(jiggleObject, "jiggleObject")
  v.regGblFun(loopObjectState, "loopObjectState")
  v.regGblFun(objectAlpha, "objectAlpha")
  v.regGblFun(objectAlphaTo, "objectAlphaTo")
  v.regGblFun(objectAt, "objectAt")
  v.regGblFun(objectBumperCycle, "objectBumperCycle")
  v.regGblFun(objectCenter, "objectCenter")
  v.regGblFun(objectColor, "objectColor")
  v.regGblFun(objectDependentOn, "objectDependentOn")
  v.regGblFun(objectFPS, "objectFPS")
  v.regGblFun(objectHidden, "objectHidden")
  v.regGblFun(objectHotspot, "objectHotspot")
  v.regGblFun(objectIcon, "objectIcon")
  v.regGblFun(objectLit, "objectLit")
  v.regGblFun(objectMoveTo, "objectMoveTo")
  v.regGblFun(objectOwner, "objectOwner")
  v.regGblFun(objectOffset, "objectOffset")
  v.regGblFun(objectOffsetTo, "objectOffsetTo")
  v.regGblFun(objectParallaxLayer, "objectParallaxLayer")
  v.regGblFun(objectParent, "objectParent")
  v.regGblFun(objectPosX, "objectPosX")
  v.regGblFun(objectPosY, "objectPosY")
  v.regGblFun(objectRenderOffset, "objectRenderOffset")
  v.regGblFun(objectRoom, "objectRoom")
  v.regGblFun(objectRotate, "objectRotate")
  v.regGblFun(objectRotateTo, "objectRotateTo")
  v.regGblFun(objectScale, "objectScale")
  v.regGblFun(objectScaleTo, "objectScaleTo")
  v.regGblFun(objectScreenSpace, "objectScreenSpace")
  v.regGblFun(objectShader, "objectShader")
  v.regGblFun(objectSort, "objectSort")
  v.regGblFun(objectState, "objectState")
  v.regGblFun(objectTouchable, "objectTouchable")
  v.regGblFun(objectUsePos, "objectUsePos")
  v.regGblFun(objectUsePosX, "objectUsePosX")
  v.regGblFun(objectUsePosY, "objectUsePosY")
  v.regGblFun(objectValidUsePos, "objectValidUsePos")
  v.regGblFun(objectValidVerb, "objectValidVerb")
  v.regGblFun(pickupObject, "pickupObject")
  v.regGblFun(pickupReplacementObject, "pickupReplacementObject")
  v.regGblFun(playObjectState, "playObjectState")
  v.regGblFun(popInventory, "popInventory")
  v.regGblFun(removeInventory, "removeInventory")
  v.regGblFun(setDefaultObject, "setDefaultObject")
  v.regGblFun(shakeObject, "shakeObject")
  v.regGblFun(stopObjectMotors, "stopObjectMotors")
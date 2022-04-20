import std/strformat, logging
import sqnim
import glm
import squtils
import vm
import ../game/engine
import ../game/ids
import ../game/room
import ../game/alphato
import ../game/rotateto
import ../game/moveto
import ../game/utils
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
    discard get(v, 2, sheet)
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
  var taAlign = taLeft
  var maxWidth = 0.0f
  if sq_gettop(v) == 4:
    var align: int
    if SQ_FAILED(get(v, 4, align)):
      return sq_throwerror(v, "failed to get align")
    let hAlign = align and 0x0000000070000000
    # let vAlign = align and 0xFFFFFFFFA1000000
    maxWidth = (align and 0x00000000000FFFFF).float
    case hAlign:
    of 0x0000000010000000:
      taAlign = taLeft;
    of 0x0000000020000000:
      taAlign = taCenter
    of 0x0000000040000000:
      taAlign = taRight
    else:
      return sq_throwerror(v, "failed to get halign")
  var obj = gEngine.room.createTextObject(fontName, text, taAlign, maxWidth)
  push(v, obj.table)
  1

proc deleteObject(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Deletes object permanently from the game. 
  ## 
  ## local drip = createObject("drip")
  ## local time = 1.5
  ## objectAt(drip, 432, 125)
  ## objectOffsetTo(drip, 0, -103, time, SLOW_EASE_IN)
  ## breaktime(time)
  ## playObjectSound(randomfrom(soundDrip1, soundDrip2, soundDrip3), radioStudioBucket)
  ## deleteObject(drip)
  var obj = obj(v, 2)
  obj.delObject()

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

proc loopObjectState(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Works exactly the same as playObjectState, but plays the animation as a continuous loop, playing the specified animation. 
  ## 
  ## .. code-block:: Squirrel
  ## loopObjectState(aStreetFire, 0)
  ## loopObjectState(flies, 3)
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  if sq_gettype(v, 3) == OT_INTEGER:
    var index: SQInteger
    if SQ_FAILED(sq_getinteger(v, 3, index)):
      return sq_throwerror(v, "failed to get state")
    obj.play(index, true)
  else:
    return sq_throwerror(v, "failed to get state")
  0

proc objectAt(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Places the specified object at the given x and y coordinates in the current room.
  ## 
  ## .. code-block:: Squirrel
  ## objectAt(text, 160,90)
  ## objectAt(obj, leftMargin, topLinePos)
  var obj = obj(v, 2)
  if obj.isNil:
    sq_throwerror(v, "failed to get object")
  else:
    var x, y: SQInteger
    if SQ_FAILED(sq_getinteger(v, 3, x)):
      return sq_throwerror(v, "failed to get x")
    if SQ_FAILED(sq_getinteger(v, 4, y)):
      return sq_throwerror(v, "failed to get y")
    obj.node.pos = vec2(x.float32, y.float32)
    0

proc objectAlpha(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets an object's alpha (transparency) in the range of 0.0 to 1.0.
  ## Setting an object's color will set it's alpha back to 1.0, ie completely opaque. 
  ## 
  ## .. code-block:: Squirrel
  ## objectAlpha(cloud, 0.5)
  var obj = obj(v, 2)
  if not obj.isNil:
    var alpha = 0.0f
    if SQ_FAILED(sq_getfloat(v, 3, alpha)):
      return sq_throwerror(v, "failed to get alpha")
    if not obj.alphaTo.isNil:
      obj.alphaTo.enabled = false
    obj.node.alpha = alpha
  0

proc objectAlphaTo(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Changes an object's alpha from its current state to the specified alpha over the time period specified by time.
  ## 
  ## If an interpolationMethod is used, the change will follow the rules of the easing method, e.g. LINEAR, EASE_INOUT.
  ## See also stopObjectMotors. 
  var obj = obj(v, 2)
  if not obj.isNil:
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
    obj.alphaTo = newAlphaTo(t, obj, alpha, interpolation.InterpolationMethod)
  0

proc objectBumperCycle(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var obj = obj(v, 2)
  if not obj.isNil:
    return sq_throwerror(v, "failed to get object")
  var enabled = 0
  if SQ_FAILED(get(v, 3, enabled)):
    return sq_throwerror(v, "failed to get enabled")
  # TODO: objectBumperCycle
  0

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
    var pos = obj.node.absolutePosition()
    push(v, rectFromPositionSize(obj.hotspot.pos + vec2(pos.x.int32, pos.y.int32), obj.hotspot.size))
    result = 1
  else:
    var left = 0
    var top = 0
    var right = 0
    var bottom = 0
    if SQ_FAILED(get(v, 3, left)):
      return sq_throwerror(v, "failed to get left")
    if SQ_FAILED(get(v, 4, top)):
      return sq_throwerror(v, "failed to get top")
    if SQ_FAILED(get(v, 5, right)):
      return sq_throwerror(v, "failed to get right")
    if SQ_FAILED(get(v, 6, bottom)):
      return sq_throwerror(v, "failed to get bottom")
    obj.hotspot = rect(left.int32, top.int32, (right-left).int32, (top-bottom).int32)
    result = 0

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
      return sq_throwerror(v, "failed to get x")
    var duration = 0.0
    if SQ_FAILED(get(v, 5, duration)):
      return sq_throwerror(v, "failed to get duration")
    var interpolation = 0
    if sq_gettop(v) >= 6 and SQ_FAILED(get(v, 6, interpolation)):
      interpolation = 0
    var destPos = vec2(x.float32, y.float32)
    obj.moveTo = newMoveTo(duration, obj, destPos, interpolation.InterpolationMethod)
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
      obj.moveTo.enabled = false
    obj.node.pos += vec2(x.float32, y.float32)
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
  var obj = obj(v, 2)
  if not obj.isNil:
    var x = 0
    var y = 0
    if SQ_FAILED(get(v, 3, x)):
      return sq_throwerror(v, "failed to get x")
    if SQ_FAILED(get(v, 4, y)):
      return sq_throwerror(v, "failed to get x")
    var duration = 0.0
    if SQ_FAILED(get(v, 5, duration)):
      return sq_throwerror(v, "failed to get duration")
    var interpolation = 0.SQInteger
    if sq_gettop(v) >= 6 and SQ_FAILED(sq_getinteger(v, 6, interpolation)):
      interpolation = 0
    var destPos = vec2(x.float32, y.float32) + obj.node.pos
    obj.moveTo = newMoveTo(duration, obj, destPos, interpolation.InterpolationMethod)
  0

proc objectParallaxLayer(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Changes the object's layer.
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  var layer = 0
  if SQ_FAILED(get(v, 3, layer)):
    return sq_throwerror(v, "failed to get parallax layer")
  gEngine.room.objectParallaxLayer(obj, layer)
  0

proc objectPosX(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns the x-coordinate of the given object or actor.
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  push(v, obj.node.absolutePosition().x + obj.usePos.x + obj.hotspot.x.float32 + obj.hotspot.w.float32 / 2.0f)

proc objectPosY(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns the y-coordinate of the given object or actor.
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  push(v, obj.node.absolutePosition().y + obj.usePos.y + obj.hotspot.y.float32 + obj.hotspot.h.float32 / 2.0f)

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
      obj.rotateTo.enabled = false
    obj.node.rotation = rotation
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
    obj.rotateTo = newRotateTo(duration, obj.node, rotation, interpolation.InterpolationMethod)
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
  var state: SQInteger
  if SQ_FAILED(sq_getinteger(v, 3, state)):
    return sq_throwerror(v, "failed to get state")
  obj.setState(state)
  0

proc objectTouchable(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets if an object is player touchable. 
  let obj = obj(v, 2)
  var touchable: SQInteger
  if SQ_FAILED(sq_getinteger(v, 3, touchable)):
    return sq_throwerror(v, "failed to get touchable")
  obj.touchable = touchable != 0
  0

proc objectSort(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ##  Sets the zsort order of an object, essentially the order in which an object is drawn on the screen.
  ## A sort order of 0 is the bottom of the screen.
  ## Actors typically have a sort order of their Y position.
  ## 
  ## .. code-block:: Squirrel
  ## objectSort(censorBox, 0)   // Will be on top of everything.
  let obj = obj(v, 2)
  var zsort: int
  if SQ_FAILED(get(v, 3, zsort)):
    return sq_throwerror(v, "failed to get zsort")
  obj.node.zOrder = zsort
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

proc register_objlib*(v: HSQUIRRELVM) =
  ## Registers the game object library
  ## 
  ## It adds all the object functions in the given Squirrel virtual machine.
  v.regGblFun(createObject, "createObject")
  v.regGblFun(createTextObject, "createTextObject")
  v.regGblFun(deleteObject, "deleteObject")
  v.regGblFun(isObject, "is_object")
  v.regGblFun(isObject, "isObject")
  v.regGblFun(loopObjectState, "loopObjectState")
  v.regGblFun(objectAlpha, "objectAlpha")
  v.regGblFun(objectAlphaTo, "objectAlphaTo")
  v.regGblFun(objectAt, "objectAt")
  v.regGblFun(objectBumperCycle, "objectBumperCycle")
  v.regGblFun(objectColor, "objectColor")
  v.regGblFun(objectFPS, "objectFPS")
  v.regGblFun(objectHidden, "objectHidden")
  v.regGblFun(objectHotspot, "objectHotspot")
  v.regGblFun(objectMoveTo, "objectMoveTo")
  v.regGblFun(objectOffset, "objectOffset")
  v.regGblFun(objectOffsetTo, "objectOffsetTo")
  v.regGblFun(objectPosX, "objectPosX")
  v.regGblFun(objectPosY, "objectPosY")
  v.regGblFun(objectParallaxLayer, "objectParallaxLayer")
  v.regGblFun(objectRoom, "objectRoom")
  v.regGblFun(objectRotate, "objectRotate")
  v.regGblFun(objectRotateTo, "objectRotateTo")
  v.regGblFun(objectScale, "objectScale")
  v.regGblFun(objectSort, "objectSort")
  v.regGblFun(objectState, "objectState")
  v.regGblFun(objectTouchable, "objectTouchable")
  v.regGblFun(playObjectState, "playObjectState")
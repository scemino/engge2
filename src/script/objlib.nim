import std/[logging, strformat]
import sqnim
import glm
import vm
import squtils
import ../game/room
import ../game/alphato
import ../game/rotateto
import ../game/utils
import ../util/easing
import ../gfx/color

proc isObject(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns true if the object is actually an object and not something else. 
  ## 
  ## .. code-block:: Squirrel
  ## if (isObject(obj) && objectValidUsePos(obj) && objectTouchable(obj)) {
  var obj: HSQOBJECT
  discard sq_getstackobj(v, 2, obj)
  push(v, obj.objType == OT_TABLE)
  1

proc objectHidden(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets if an object is hidden or not. If the object is hidden, it is no longer displayed or touchable. 
  ## 
  ## .. code-block:: Squirrel
  ## objectHidden(oldRags, YES)
  var table: HSQOBJECT
  discard sq_getstackobj(v, 2, table)
  var hidden: int
  discard sq_getinteger(v, 3, hidden)
  var obj = obj(table)
  obj.visible = hidden == 0
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
    alpha = clamp(alpha, 0.0f, 1.0f);
    obj.color = rgbf(obj.color, alpha)
  0

proc objectAlphaTo(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Changes an object's alpha from its current state to the specified alpha over the time period specified by time.
  ## If an interpolationMethod is used, the change will follow the rules of the easing method, e.g. LINEAR, EASE_INOUT.
  ## See also stopObjectMotors. 
  var obj = obj(v, 2)
  if not obj.isNil:
    var alpha = 0.0f
    if SQ_FAILED(sq_getfloat(v, 3, alpha)):
      return sq_throwerror(v, "failed to get alpha")
    alpha = clamp(alpha, 0.0f, 1.0f);
    var t = 0.0f
    if SQ_FAILED(sq_getfloat(v, 4, t)):
      return sq_throwerror(v, "failed to get time")
    var interpolation: SQInteger
    if SQ_FAILED(sq_getinteger(v, 5, interpolation)):
      interpolation = 0
    obj.alphaTo = newAlphaTo(t, obj, alpha, interpolation.InterpolationMethod)
  0

proc objectRotateTo(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var obj = obj(v, 2)
  if not obj.isNil:
    var rotation = 0.0f
    if SQ_FAILED(sq_getfloat(v, 3, rotation)):
      return sq_throwerror(v, "failed to get rotation")
    var duration = 0.0f
    if SQ_FAILED(sq_getfloat(v, 4, duration)):
      return sq_throwerror(v, "failed to get duration")
    var interpolation = 0.SQInteger
    if sq_gettop(v) != 5 or SQ_FAILED(sq_getinteger(v, 5, interpolation)):
      interpolation = 0
    obj.alphaTo = newRotateTo(duration, obj.node, rotation, interpolation.InterpolationMethod)
  0

proc objectAt(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var obj = obj(v, 2)
  if obj.isNil:
    sq_throwerror(v, "failed to get object")
  else:
    var x, y: SQInteger
    if SQ_FAILED(sq_getinteger(v, 3, x)):
      return sq_throwerror(v, "failed to get x")
    if SQ_FAILED(sq_getinteger(v, 4, y)):
      return sq_throwerror(v, "failed to get y")
    obj.pos = vec2(x.float32, y.float32)
    0

proc objectState(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let obj = obj(v, 2)
  var state: SQInteger
  if SQ_FAILED(sq_getinteger(v, 3, state)):
    return sq_throwerror(v, "failed to get state")
  obj.animIndex = state
  0

proc objectTouchable(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets if an object is player touchable. 
  let obj = obj(v, 2)
  var touchable: SQInteger
  if SQ_FAILED(sq_getinteger(v, 3, touchable)):
    return sq_throwerror(v, "failed to get touchable")
  obj.touchable = touchable != 0
  0

proc playObjectState(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var obj = obj(v, 2)
  var state: string
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  if sq_gettype(v, 3) == OT_INTEGER:
    var index: SQInteger
    if SQ_FAILED(sq_getinteger(v, 3, index)):
      return sq_throwerror(v, "failed to get state")
    state = "state" & $index
  elif sq_gettype(v, 3) == OT_STRING:
    var sqState: SQString
    if SQ_FAILED(sq_getstring(v, 3, sqState)):
      return sq_throwerror(v, "failed to get state")
    state = $sqState
  else:
    return sq_throwerror(v, "failed to get state")
  
  for i in 0..<obj.anims.len:
    let anim = obj.anims[i].name
    if anim == state:
      info fmt"playObjectState {obj.name}, {state} ({i})"
      # TODO
      return 0
  0

proc register_objlib*(v: HSQUIRRELVM) =
  ## Registers the game object library
  ## 
  ## It adds all the object functions in the given Squirrel virtual machine.
  v.regGblFun(isObject, "isObject")
  v.regGblFun(objectHidden, "objectHidden")
  v.regGblFun(objectAlpha, "objectAlpha")
  v.regGblFun(objectAlphaTo, "objectAlphaTo")
  v.regGblFun(objectAt, "objectAt")
  v.regGblFun(objectRotateTo, "objectRotateTo")
  v.regGblFun(objectState, "objectState")
  v.regGblFun(objectTouchable, "objectTouchable")
  v.regGblFun(playObjectState, "playObjectState")
import std/[logging, options, strformat]
import sqnim
import glm
import vm
import engine
import squtils
import utils
import room
import alphato
import ../gfx/color

proc isObject(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var obj: HSQOBJECT
  discard sq_getstackobj(v, 2, obj)
  push(v, obj.objType == OT_TABLE)
  1

proc objectHidden(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var table: HSQOBJECT
  discard sq_getstackobj(v, 2, table)
  var hidden: int
  discard sq_getinteger(v, 3, hidden)
  var obj = obj(table)
  obj.visible = hidden == 0
  0

proc getObj(v: HSQUIRRELVM, i: int): Option[Object] =
  var obj: HSQOBJECT
  discard sq_getstackobj(v, i, obj)
  var name: string
  getf(v, obj, "name", name)
  for o in gEngine.room.objects.mitems:
    if o.name == name:
      return some(o)
  none(Object)

proc objectAlpha(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var obj = getObj(v, 2)
  if obj.isSome:
    var alpha = 0.0f
    if SQ_FAILED(sq_getfloat(v, 3, alpha)):
      return sq_throwerror(v, "failed to get alpha")
    alpha = clamp(alpha, 0.0f, 1.0f);
    let color = obj.get.color
    obj.get.color = rgbf(color, alpha)
  0

proc objectAlphaTo(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var obj = getObj(v, 2)
  if obj.isSome:
    var alpha = 0.0f
    if SQ_FAILED(sq_getfloat(v, 3, alpha)):
      return sq_throwerror(v, "failed to get alpha")
    alpha = clamp(alpha, 0.0f, 1.0f);
    var t = 0.0f
    if SQ_FAILED(sq_getfloat(v, 4, t)):
      return sq_throwerror(v, "failed to get time")
    obj.get.alphaTo = newAlphaTo(t, obj.get, alpha)
  0

proc objectAt(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var obj = getObj(v, 2)
  if obj.isNone:
    sq_throwerror(v, "failed to get object")
  else:
    var x, y: SQInteger
    if SQ_FAILED(sq_getinteger(v, 3, x)):
      return sq_throwerror(v, "failed to get x")
    if SQ_FAILED(sq_getinteger(v, 4, y)):
      return sq_throwerror(v, "failed to get y")
    obj.get.pos = vec2(x.float32, y.float32)
    0

proc objectState(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let obj = getObj(v, 2)
  var state: SQInteger
  if SQ_FAILED(sq_getinteger(v, 3, state)):
    return sq_throwerror(v, "failed to get state")
  obj.get.animationIndex = state
  0

proc playObjectState(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var obj = getObj(v, 2)
  var state: string
  if obj.isNone:
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
  
  for i in 0..<obj.get.animations.len:
    let anim = obj.get.animations[i].name
    if anim == state:
      info fmt"playObjectState {obj.get.name}, {state} ({i})"
      obj.get.animationIndex = i
      obj.get.play()
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
  v.regGblFun(objectState, "objectState")
  v.regGblFun(playObjectState, "playObjectState")
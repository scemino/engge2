import std/random as rnd
import std/logging
import std/strformat
import sqnim
import glm
import squtils
import ../game/campanto
import ../game/room
import ../game/utils
import ../game/engine
import ../gfx/graphics
import ../util/easing
import ../scenegraph/node

proc cameraAt(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let numArgs = sq_gettop(v)
  var pos: Vec2f
  if numArgs == 3:
    var x, y: SQInteger
    if SQ_FAILED(sq_getinteger(v, 2, x)):
      return sq_throwerror(v, "failed to get x")
    if SQ_FAILED(sq_getinteger(v, 3, y)):
      return sq_throwerror(v, "failed to get y")
    pos = vec2(x.float32, y.float32)
  elif numArgs == 2:
    var obj = obj(v, 2)
    pos = obj.node.absolutePosition()
  else:
    return sq_throwerror(v, fmt"invalid argument number: {numArgs}".cstring)
  info fmt"cameraAt: {pos}"
  if not gEngine.cameraPanTo.isNil:
    gEngine.cameraPanTo.enabled = false
  gEngine.cameraAt(pos - camera() / 2.0f)
  0

proc cameraPanTo(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let numArgs = sq_gettop(v)
  var pos: Vec2f
  var duration: float
  var interpolation: InterpolationMethod
  if numArgs == 4:
    var obj = obj(v, 2)
    if SQ_FAILED(get(v, 3, duration)):
      return sq_throwerror(v, "failed to get duration")
    var im: int
    if SQ_FAILED(get(v, 4, im)):
      return sq_throwerror(v, "failed to get interpolation method")
    pos = obj.node.absolutePosition()
    interpolation = im.InterpolationMethod
  elif numArgs == 5:
    var x, y: int
    if SQ_FAILED(get(v, 2, x)):
      return sq_throwerror(v, "failed to get x")
    if SQ_FAILED(get(v, 3, y)):
      return sq_throwerror(v, "failed to get y")
    if SQ_FAILED(get(v, 4, duration)):
      return sq_throwerror(v, "failed to get duration")
    var im: int
    if SQ_FAILED(get(v, 5, im)):
      return sq_throwerror(v, "failed to get interpolation method")
    pos = vec2(x.float32, y.float32)
    interpolation = im.InterpolationMethod
  else:
    return sq_throwerror(v, fmt"invalid argument number: {numArgs}".cstring)
  info fmt"cameraPanTo: {pos}, dur={duration}, method={interpolation}"
  gEngine.cameraPanTo = newCameraPanTo(duration, pos, interpolation)
  0

proc random(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  if sq_gettype(v, 2) == OT_INTEGER:
    var min, max: int
    discard sq_getinteger(v, 2, min)
    discard sq_getinteger(v, 3, max)
    let value = gEngine.rand.rand(min..max)
    sq_pushinteger(v, value)
    return 1
  else:
    var min, max: SQFloat
    discard sq_getfloat(v, 2, min)
    discard sq_getfloat(v, 3, max)
    let value = gEngine.rand.rand(min..max)
    sq_pushfloat(v, value)
    return 1

proc randomFrom(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  if sq_gettype(v, 2) == OT_ARRAY:
    var obj: HSQOBJECT
    sq_resetobject(obj)
    let size = sq_getsize(v, 2)
    let index = gEngine.rand.rand(0..size - 1)
    var i = 0
    sq_push(v, 2)  # array
    sq_pushnull(v) # null iterator
    while SQ_SUCCEEDED(sq_next(v, -2)):
      discard sq_getstackobj(v, -1, obj)
      sq_pop(v, 2) # pops key and val before the nex iteration
      if index == i:
        sq_pop(v, 2) # pops the null iterator and array
        sq_pushobject(v, obj)
        return 1
      i += 1
    sq_pop(v, 1) # pops the null iterator and array
    sq_pushobject(v, obj)
  else:
    let size = sq_gettop(v)
    let index = gEngine.rand.rand(0..size - 2)
    sq_push(v, 2 + index)
  1
  
proc randomOdds(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var value = 0.0f
  if SQ_FAILED(sq_getfloat(v, 2, value)):
    return sq_throwerror(v, "failed to get value")
  let rnd = gEngine.rand.rand(0.0f..1.0f)
  let res = rnd <= value
  sq_pushbool(v, res)
  1

proc register_generallib*(v: HSQUIRRELVM) =
  ## Registers the game general library
  ## 
  ## It adds all the general functions in the given Squirrel virtual machine.
  v.regGblFun(cameraAt, "cameraAt")
  v.regGblFun(cameraPanTo, "cameraPanTo")
  v.regGblFun(random, "random")
  v.regGblFun(randomFrom, "randomfrom")
  v.regGblFun(randomOdds, "randomOdds")
  
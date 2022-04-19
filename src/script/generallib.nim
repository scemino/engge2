import std/random as rnd
import std/logging
import std/strformat
import std/streams
import sqnim
import glm
import squtils
import vm
import ../game/campanto
import ../game/room
import ../game/utils
import ../game/engine
import ../gfx/graphics
import ../util/easing
import ../scenegraph/node
import ../io/ggpackmanager

proc assetExists(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns TRUE if the specified entry exists in the assets.
  var filename: string
  if SQ_FAILED(get(v, 2, filename)):
      return sq_throwerror(v, "failed to get filename")
  push(v, gGGPackMgr.assetExists(filename))
  1

proc cameraAt(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Moves the camera to the specified x, y location.
  ## If a spot is specified, will move to the x, y specified by that spot.
  ## .. code-block:: Squirrel
  ## cameraAt(450, 128)
  ## 
  ## enterRoomFromDoor(Bridge.startRight)
  ## actorAt(ray, Bridge.startLeft)
  ## actorAt(reyes, Bridge.startRight)
  ## cameraAt(Bridge.bridgeBody)
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
  if not gEngine.cameraPanTo.isNil:
    gEngine.cameraPanTo.enabled = false
  var screenSize = gEngine.room.getScreenSize()
  var at = pos - vec2(screenSize.x.float32, screenSize.y.float32) / 2.0f
  gEngine.cameraAt(at)
  0

proc cameraPanTo(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Pans the camera to the specified x, y location over the duration using the transition method.
  ## Transition methods are: EASE_IN, EASE_INOUT, EASE_OUT, LINEAR, SLOW_EASE_IN, SLOW_EASE_OUT.
  ## 
  ## .. code-block:: Squirrel
  ## cameraPanTo(450, 128, pan_time, EASE_INOUT)
  ## inputOff()
  ## actorWalkTo(currentActor, Highway.detectiveSpot1)
  ## breakwhilewalking(currentActor)
  ## cameraPanTo(currentActor, 2.0)
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

proc cameraPos(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns the current camera position x, y.
  push(v, gEngine.cameraPos())
  1

proc is_oftype(v: HSQUIRRELVM, types: openArray[SQ_ObjectType]): SQInteger =
  push(v, sq_gettype(v, 2) in types)
  1

proc is_array(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  is_oftype(v, [OT_ARRAY])

proc is_function(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  is_oftype(v, [OT_CLOSURE, OT_NATIVECLOSURE])

proc loadArray(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns an array of all the lines of the given `filename`. 
  var filename: string
  if SQ_FAILED(get(v, 2, filename)):
    return sq_throwerror(v, "failed to get filename")
  sq_newarray(v, 0)
  for line in gGGPackMgr.loadStream(filename).lines():
    sq_pushstring(v, line.cstring, -1)
    discard sq_arrayappend(v, -2)
  1

proc random(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns a random number from from to to inclusively.
  ## The number is a pseudo-random number and the game will produce the same sequence of numbers unless primed using randomSeed(seed).
  ## 
  ## .. code-block:: Squirrel
  ## num = random(1, 10)   // Returns an int
  ## wait_time = random(0.5, 2.0)   // Returns a float
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
  ## Selects an item randomly from the given array or listed options. 
  ## 
  ## .. code-block:: Squirrel
  ## local line = randomfrom(lines)
  ## breakwhiletalking(willie)
  ## mumbleLine(willie, line)
  ## 
  ## local snd = randomfrom(soundBeep1, soundBeep2, soundBeep3, soundBeep4, soundBeep5, soundBeep6)
  ## playObjectSound(snd, Highway.pigeonVan)
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
  ## Returns TRUE or FALSE based on the percent, which needs to be from 0.0 to 1.0.
  ## 
  ## A percent of 0.0 will always return FALSE and 1.0 will always return TRUE.
  ## `randomOdds(0.3333)` will return TRUE about one third of the time. 
  ## 
  ## .. code-block:: Squirrel
  ## if (randomOdds(0.5) { ... }
  var value = 0.0f
  if SQ_FAILED(sq_getfloat(v, 2, value)):
    return sq_throwerror(v, "failed to get value")
  let rnd = gEngine.rand.rand(0.0f..1.0f)
  let res = rnd <= value
  sq_pushbool(v, res)
  1

proc randomseed(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Initializes a new Rand state using the given seed.
  ## Providing a specific seed will produce the same results for that seed each time.
  ## The resulting state is independent of the default RNG's state.
  let nArgs = sq_gettop(v)
  case nArgs:
  of 1:
    push(v, gEngine.seed)
    return 1
  of 2:
    var seed = 0
    if sq_gettype(v, 2) == OT_NULL:
      gEngine.seedWithTime()  
      return 0
    if SQ_FAILED(get(v, 2, seed)):
      return sq_throwerror(v, "failed to get seed")
    gEngine.seed = seed
    return 0
  else:
    sq_throwerror(v, "invalid number of parameters for randomseed")

proc screenSize(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns the x and y dimensions of the current screen/window.
  ## 
  ## .. code-block:: Squirrel
  ## function clickedAt(x,y) {
  ##     local screenHeight = screenSize().y
  ##     local exitButtonB = screenHeight - (exitButtonPadding + 16)
  ##     if (y > exitButtonB) { ... }
  ## }
  var screen = gEngine.room.getScreenSize()
  push(v, screen)
  return 1;

proc register_generallib*(v: HSQUIRRELVM) =
  ## Registers the game general library
  ## 
  ## It adds all the general functions in the given Squirrel virtual machine.
  v.regGblFun(assetExists, "assetExists")
  v.regGblFun(cameraAt, "cameraAt")
  v.regGblFun(cameraPanTo, "cameraPanTo")
  v.regGblFun(cameraPos, "cameraPos")
  v.regGblFun(is_array, "is_array")
  v.regGblFun(is_function, "is_function")
  v.regGblFun(loadArray, "loadArray")
  v.regGblFun(random, "random")
  v.regGblFun(randomFrom, "randomfrom")
  v.regGblFun(randomOdds, "randomOdds")
  v.regGblFun(randomOdds, "randomodds")
  v.regGblFun(randomseed, "randomseed")
  v.regGblFun(screenSize, "screenSize")
  
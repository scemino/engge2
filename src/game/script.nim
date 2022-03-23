import std/[logging, strutils, options]
import std/random as rnd
import sqnim
import thread
import vm
import engine
import squtils
import room
import alphato
import ../gfx/color
import ../util/tween
import ../util/easing

# private methods
proc sqChr(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var value: int
  get(v, 2, value)
  var s: string
  s.add(chr(value))
  push(v, s)
  1

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

proc randomOdds(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var value = 0.0f
  if SQ_FAILED(sq_getfloat(v, 2, value)):
    return sq_throwerror(v, "failed to get value")
  let rnd = gEngine.rand.rand(0.0f..1.0f)
  let res = rnd <= value
  sq_pushbool(v, res)
  1

proc pstartthread(v: HSQUIRRELVM, global: bool): SQInteger {.cdecl.} =
  let size = sq_gettop(v)
  var env_obj: HSQOBJECT
  sq_resetobject(env_obj)
  if SQ_FAILED(sq_getstackobj(v, 1, env_obj)):
    return sq_throwerror(v, "Couldn't get environment from stack")

  # create thread and store it on the stack
  discard sq_newthread(v, 1024)
  var thread_obj: HSQOBJECT
  sq_resetobject(thread_obj)
  if SQ_FAILED(sq_getstackobj(v, -1, thread_obj)):
    return sq_throwerror(v, "Couldn't get coroutine thread from stack")

  var args: seq[HSQOBJECT]
  for i in 0..<size-2:
    var arg: HSQOBJECT
    sq_resetobject(arg)
    if SQ_FAILED(sq_getstackobj(v, 3 + i, arg)):
      return sq_throwerror(v, "Couldn't get coroutine args from stack")
    args.add(arg)

  # get the closure
  var closureObj: HSQOBJECT
  sq_resetobject(closureObj)
  if SQ_FAILED(sq_getstackobj(v, 2, closureObj)):
    return sq_throwerror(v, "Couldn't get coroutine thread from stack")

  var name: cstring
  if SQ_SUCCEEDED(sq_getclosurename(v, 2)):
    discard sq_getstring(v, -1, name)

  let threadName = if not name.isNil: name else: "anonymous"
  var thread = newThread($threadName, global, v, thread_obj, env_obj, closureObj, args)
  sq_pop(v, 1)
  info("create thread (" & $threadName & ")")
  if not name.isNil:
    sq_pop(v, 1) # pop name
  sq_pop(v, 1) # pop closure
  gThreads.add(thread)

  sq_pushinteger(v, thread.id)
  return 1

proc startthread(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  pstartthread(v, false)

proc stopthread(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var id: int
  if SQ_FAILED(sq_getinteger(v, 2, id)):
    sq_pushinteger(v, 0)
    return 1

  for t in gThreads:
    if t.id == id:
      t.stop()
      sq_pushinteger(v, 0)
      return 1

  sq_pushinteger(v, 0)
  1

proc startglobalthread(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  pstartthread(v, true)

proc breakfunc(v: HSQUIRRELVM, setConditionFactory: proc (t: Thread)): SQInteger =
  for t in gThreads:
    if t.getThread() == v:
      t.suspend()
      setConditionFactory(t)
      return -666
  sq_throwerror(v, "failed to get thread")

proc breakhere(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var numFrames: SQInteger
  if SQ_FAILED(sq_getinteger(v, 2, numFrames)):
    return sq_throwerror(v, "failed to get numFrames")
  breakfunc(v, proc (t: Thread) = t.numFrames = numFrames)

proc breaktime(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var time: SQFloat
  if SQ_FAILED(sq_getfloat(v, 2, time)):
    return sq_throwerror(v, "failed to get time")
  breakfunc(v, proc (t: Thread) = t.waitTime = time)

proc defineRoom(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var room: HSQOBJECT
  discard sq_getstackobj(v, 2, room)
  gEngine.setRoom(room)

proc isObject(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var obj: HSQOBJECT
  discard sq_getstackobj(v, 2, obj)
  push(v, obj.objType == OT_TABLE)
  1

proc objectHidden(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var obj: HSQOBJECT
  discard sq_getstackobj(v, 2, obj)
  var hidden: int
  discard sq_getinteger(v, 3, hidden)
  var name: string
  getf(v, obj, "name", name)
  for o in gEngine.room.objects.mitems:
    if o.name == name:
      o.visible = hidden == 0
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
  else:
    let size = sq_gettop(v)
    let index = gEngine.rand.rand(0..size - 2)
    sq_push(v, 2 + index)
  1

proc roomFade(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var fadeType: SQInteger
  var t: SQFloat
  if SQ_FAILED(sq_getinteger(v, 2, fadeType)):
    return sq_throwerror(v, "failed to get fadeType")
  if SQ_FAILED(sq_getfloat(v, 3, t)):
    return sq_throwerror(v, "failed to get time")
  if fadeType == 0: # FadeIn
    gEngine.fade = newTween[float](1.0f, 0.0f, t, linear)
  elif fadeType == 1: # FadeOut
    gEngine.fade = newTween[float](0.0f, 1.0f, t, linear)
  0

#public methods
proc register_gamelib*(v: HSQUIRRELVM) =
  v.regGblFun(startglobalthread, "startglobalthread")
  v.regGblFun(startthread, "startthread")
  v.regGblFun(stopthread, "stopthread")
  v.regGblFun(breakhere, "breakhere")
  v.regGblFun(breaktime, "breaktime")
  v.regGblFun(random, "random")
  v.regGblFun(sqChr, "chr")
  v.regGblFun(defineRoom, "defineRoom")
  v.regGblFun(isObject, "isObject")
  v.regGblFun(objectHidden, "objectHidden")
  v.regGblFun(objectAlpha, "objectAlpha")
  v.regGblFun(objectAlphaTo, "objectAlphaTo")
  v.regGblFun(randomFrom, "randomfrom")
  v.regGblFun(randomOdds, "randomOdds")
  v.regGblFun(roomFade, "roomFade")

proc register_gameconstants*(v: HSQUIRRELVM) =
  sqBind(v):
    const 
      ALL = 1
      HERE = 0
      GONE = 4
      OFF = 0
      ON = 1
      FULL = 0
      EMPTY = 1
      OPEN = 1
      CLOSED = 0
      FALSE = 0
      TRUE = 0
      MOUSE = 1
      CONTROLLER = 2
      DIRECTDRIVE = 3
      TOUCH = 4
      REMOTE = 5
      FADE_IN = 0
      FADE_OUT = 1
      FADE_WOBBLE = 2
      FADE_WOBBLE_TO_SEPIA = 3
      FACE_FRONT = 4
      FACE_BACK = 8
      FACE_LEFT = 2
      FACE_RIGHT = 1
      FACE_FLIP = 16
      DIR_FRONT = 4
      DIR_BACK = 8
      DIR_LEFT = 2
      DIR_RIGHT = 1
      LINEAR = 0
      EASE_IN = 1
      EASE_INOUT = 2
      EASE_OUT = 3
      SLOW_EASE_IN = 4
      SLOW_EASE_OUT = 5
      LOOPING = 0x100
      SWING = 0X200
      ALIGN_LEFT =   0x0000000010000000
      ALIGN_CENTER = 0x0000000020000000
      ALIGN_RIGHT =  0x0000000040000000
      ALIGN_TOP =    0xFFFFFFFF80000000
      ALIGN_BOTTOM = 0x0000000001000000
      LESS_SPACING = 0x0000000000200000
      EX_ALLOW_SAVEGAMES = 1
      EX_POP_CHARACTER_SELECTION = 2
      EX_CAMERA_TRACKING = 3
      EX_BUTTON_HOVER_SOUND = 4
      EX_RESTART = 6
      EX_IDLE_TIME = 7
      EX_AUTOSAVE = 8
      EX_AUTOSAVE_STATE = 9
      EX_DISABLE_SAVESYSTEM = 10
      EX_SHOW_OPTIONS = 11
      EX_OPTIONS_MUSIC = 12
      EX_FORCE_TALKIE_TEXT = 13
      GRASS_BACKANDFORTH = 0x00
      EFFECT_NONE = 0x00
      DOOR = 0x40
      DOOR_LEFT = 0x140
      DOOR_RIGHT = 0x240
      DOOR_BACK = 0x440
      DOOR_FRONT = 0x840
      FAR_LOOK = 0x8
      USE_WITH = 2
      USE_ON = 4
      USE_IN = 32
      GIVEABLE = 0x1000
      TALKABLE = 0x2000
      IMMEDIATE = 0x4000
      FEMALE = 0x80000
      MALE = 0x100000
      PERSON = 0x200000
      REACH_HIGH = 0x8000
      REACH_MED = 0x10000
      REACH_LOW = 0x20000
      REACH_NONE = 0x40000
      VERB_CLOSE = 6
      VERB_GIVE = 9
      VERB_LOOKAT = 2
      VERB_OPEN = 5
      VERB_PICKUP = 4
      VERB_PULL = 8
      VERB_PUSH = 7
      VERB_TALKTO = 3
      VERB_USE = 10
      VERB_WALKTO = 1
      VERB_DIALOG = 13
      VERBFLAG_INSTANT = 1
      NO = 0
      YES = 1
      UNSELECTABLE = 0
      SELECTABLE = 1
      TEMP_UNSELECTABLE = 2
      TEMP_SELECTABLE = 3
      MAC = 1
      WIN = 2
      LINUX = 3
      XBOX = 4
      IOS = 5
      ANDROID = 6
      SWITCH = 7
      PS4 = 8

import engine
import sqnim
import squtils
import ../util/tween
import ../util/easing

proc defineRoom(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var room: HSQOBJECT
  discard sq_getstackobj(v, 2, room)
  gEngine.setRoom(room)

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

proc register_roomlib*(v: HSQUIRRELVM) =
  ## Registers the game room library
  ## 
  ## It adds all the room functions in the given Squirrel virtual machine.
  v.regGblFun(defineRoom, "defineRoom")
  v.regGblFun(roomFade, "roomFade")
  
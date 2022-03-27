import engine
import sqnim
import squtils
import utils
import ids
import ../util/tween
import ../util/easing

proc defineRoom(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var table: HSQOBJECT
  sq_resetobject(table)
  discard sq_getstackobj(v, 2, table)
  var name: string
  v.getf(table, "background", name)
  var room = loadRoom(name)
  gEngine.rooms.add room
  0

proc cameraInRoom(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var table: HSQOBJECT
  sq_resetobject(table)
  discard sq_getstackobj(v, 2, table)
  let id = table.getId()
  if id == 0:
    return sq_throwerror(v, "failed to get room 1")
  if id >= START_ROOMID and id < END_ROOMID:
    gEngine.setRoom(room(id))
  if id >= START_OBJECTID and id < END_OBJECTID:
    let room = objRoom(table)
    if room.isNil:
      return sq_throwerror(v, "failed to get room 2")
    gEngine.setRoom(room)
  0

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
  v.regGblFun(cameraInRoom, "cameraInRoom")
  v.regGblFun(defineRoom, "defineRoom")
  v.regGblFun(roomFade, "roomFade")
  
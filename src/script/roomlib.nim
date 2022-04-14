import std/strformat
import std/logging
import sqnim
import squtils
import ../game/utils
import ../game/ids
import ../game/overlayto
import ../game/engine
import ../util/tween
import ../util/easing
import ../gfx/color

proc defineRoom(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## This command is used during the game's boot process. 
  ## `defineRoom` is called once for every room in the game, passing it the room's room object.
  ## If the room has not been defined, it can not be referenced. 
  ## `defineRoom` is typically called in the the DefineRooms.nut file which loads and defines every room in the game. 
  var table: HSQOBJECT
  sq_resetobject(table)
  discard sq_getstackobj(v, 2, table)
  var name: string
  v.getf(table, "background", name)
  var room = loadRoom(name)
  info fmt"define room: {name}"
  gEngine.rooms.add room
  0

proc cameraInRoom(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Moves the camera to the specified room.
  ## 
  ## Does not move any of the actors.
  ## 
  ## .. code-block:: Squirrel
  ## aStreetPhoneBook =
  ## {
  ##     name = "phone book"
  ##     verbLookAt = function()
  ##     {
  ##         cameraInRoom(PhoneBook)
  ##      }
  ## }
  var table: HSQOBJECT
  sq_resetobject(table)
  discard sq_getstackobj(v, 2, table)
  let id = table.getId()
  if id.isRoom():
    gEngine.setRoom(room(id))
  elif id.isObject():
    let room = objRoom(table)
    if room.isNil:
      return sq_throwerror(v, "failed to get room")
    gEngine.setRoom(room)
  else:
    return sq_throwerror(v, "failed to get room")
  0

proc roomFade(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Fades in or out (FADE_IN, FADE_OUT ) of the current room over the specified duration. 
  ## 
  ## Used for dramatic effect when we want to teleport the player actor to somewhere new, or when starting/ending a cutscene that takes place in another room. 
  ## .. code-block:: Squirrel
  ## roomFade(FADE_OUT, 0.5)
  ## breaktime(0.5)
  ## actorAt(currentActor, Alleyway.newLocationSpot)
  ## cameraFollow(currentActor)
  ## roomFade(FADE_IN, 0.5)
  var fadeType: SQInteger
  var t: SQFloat
  if SQ_FAILED(sq_getinteger(v, 2, fadeType)):
    return sq_throwerror(v, "failed to get fadeType")
  if SQ_FAILED(sq_getfloat(v, 3, t)):
    return sq_throwerror(v, "failed to get time")
  if fadeType == 0: # FadeIn
    gEngine.fade = newTween[float](1.0f, 0.0f, t, imLinear)
  elif fadeType == 1: # FadeOut
    gEngine.fade = newTween[float](0.0f, 1.0f, t, imLinear)
  0

proc roomOverlayColor(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Puts a color overlay on the top of the entire room.
  ## 
  ## Transition from startColor to endColor over duration seconds.
  ## The endColor remains on screen until changed.
  ## Note that the actual colour is an 8 digit number, the first two digits (00-ff) represent the transparency, while the last 6 digits represent the actual colour. 
  ## If transparency is set to 00, the overlay is completely see through.
  ## If startColor is not on the screen already, it will flash to that color before starting the transition. 
  ## If no endColor or duration are provided, it will change instantly to color and remain there. 
  ## 
  ## .. code-block:: Squirrel
  ## // Make lights in QuickiePal flicker
  ## roomOverlayColor(0x20dff2cd, 0x20dff2cd, 0.0)
  ## breaktime(1/60)
  ## roomOverlayColor(0x00000000, 0x00000000, 0.0)
  ## breaktime(1/60)
  ## 
  ## if (currentActor == franklin) {
  ##     roomOverlayColor(0x800040AA)
  ## }
  var startColor: SQInteger
  var numArgs = sq_gettop(v)
  if SQ_FAILED(sq_getinteger(v, 2, startColor)):
    return sq_throwerror(v, "failed to get startColor")
  let room = gEngine.room
  room.overlay = rgba(startColor.int)
  if numArgs == 4:
    var endColor: SQInteger
    if SQ_FAILED(sq_getinteger(v, 3, endColor)):
      return sq_throwerror(v, "failed to get endColor")
    var duration: SQFloat
    if SQ_FAILED(sq_getfloat(v, 4, duration)):
      return sq_throwerror(v, "failed to get duration")
    info fmt"start overlay from {rgba(startColor)} to {rgba(endColor)} in {duration}s"
    var overlayTo = newOverlayTo(duration, room, rgba(startColor), rgba(endColor))
    gEngine.tasks.add overlayTo
  0

proc register_roomlib*(v: HSQUIRRELVM) =
  ## Registers the game room library
  ## 
  ## It adds all the room functions in the given Squirrel virtual machine.
  v.regGblFun(cameraInRoom, "cameraInRoom")
  v.regGblFun(defineRoom, "defineRoom")
  v.regGblFun(roomFade, "roomFade")
  v.regGblFun(roomOverlayColor, "roomOverlayColor")
  
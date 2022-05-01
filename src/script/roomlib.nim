import std/strformat
import std/tables
import std/logging
import sqnim
import squtils
import ../util/utils
import ../game/engine
import ../game/overlayto
import ../game/room
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

proc masterRoomArray(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns an array of all the rooms that are in the game currently.
  ## 
  ## This is useful for testing.
  ##
  ## .. code-block:: Squirrel
  ## local roomArray = masterRoomArray()
  ## foreach (room in roomArray) {
  ##     enterRoomFromDoor(room)
  ##     breaktime(0.10)
  ## }
  sq_newarray(v, 0)
  for room in gEngine.rooms:
    sq_pushobject(v, room.table)
    discard sq_arrayappend(v, -2)
  1

proc roomActors(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns an array of all the actors in the specified room.
  ## 
  ## .. code-block:: Squirrel
  ## local actorInBookstore = roomActors(BookStore)
  ## if (actorInBookstore.len()>1) { ... }
  ## 
  ## local spotters = roomActors(currentRoom)
  ## foreach(actor in spotters) { ...}
  var room = room(v, 2)
  if room.isNil:
    return sq_throwerror(v, "failed to get room")
  sq_newarray(v, 0)
  for actor in gEngine.actors:
    if actor.room == room:
      sq_pushobject(v, room.table)
      discard sq_arrayappend(v, -2)
  1

proc roomFade(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Fades in or out (FADE_IN, FADE_OUT ) of the current room over the specified duration. 
  ## 
  ## Used for dramatic effect when we want to teleport the player actor to somewhere new, or when starting/ending a cutscene that takes place in another room. 
  ## 
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

proc roomLayer(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Makes all layers at the specified zsort value in room visible (YES) or invisible (NO).
  ## It's also currently the only way to affect parallax layers and can be used for minor animation to turn a layer on and off. 
  ## 
  ## .. code-block:: Squirrel
  ## roomLayer(GrateEntry, -2, NO)  // Make lights out layer invisible
  var r = room(v, 2)
  var layer, enabled: SQInteger
  if SQ_FAILED(sq_getinteger(v, 3, layer)):
    return sq_throwerror(v, "failed to get layer")
  if SQ_FAILED(sq_getinteger(v, 4, enabled)):
    return sq_throwerror(v, "failed to get enabled")
  r.layer(layer).node.visible = enabled != 0
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

proc walkboxHidden(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets walkbox to be hidden (YES) or not (NO).
  ## If the walkbox is hidden, the actors cannot walk to any point within that area anymore, nor to any walkbox that's connected to it on the other side from the actor.
  ## Often used on small walkboxes below a gate or door to keep the actor from crossing that boundary if the gate/door is closed. 
  var walkbox: string
  if SQ_FAILED(get(v, 2, walkbox)):
    return sq_throwerror(v, "failed to get object or walkbox")
  var hidden = 0
  if SQ_FAILED(get(v, 3, hidden)):
    return sq_throwerror(v, "failed to get object or hidden")
  gEngine.room.walkboxHidden(walkbox, hidden != 0)
  0

proc register_roomlib*(v: HSQUIRRELVM) =
  ## Registers the game room library
  ## 
  ## It adds all the room functions in the given Squirrel virtual machine.
  v.regGblFun(defineRoom, "defineRoom")
  v.regGblFun(masterRoomArray, "masterRoomArray")
  v.regGblFun(roomActors, "roomActors")
  v.regGblFun(roomFade, "roomFade")
  v.regGblFun(roomLayer, "roomLayer")
  v.regGblFun(roomOverlayColor, "roomOverlayColor")
  v.regGblFun(walkboxHidden, "walkboxHidden")
  
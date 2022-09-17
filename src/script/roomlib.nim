import std/strformat
import std/logging
import glm
import sqnim
import squtils
import ../util/utils
import ../game/engine
import ../game/motors/overlayto
import ../game/motors/rotateto
import ../game/motors/motor
import ../game/room
import ../game/shaders
import ../game/walkbox
import ../util/tween
import ../util/easing
import ../gfx/color
import ../script/vm

proc addTrigger(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let nArgs = sq_gettop(v)
  let obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  sq_resetobject(obj.enter)
  sq_resetobject(obj.leave)
  if SQ_FAILED(get(v, 3, obj.enter)):
    return sq_throwerror(v, "failed to get enter")
  sq_addref(gVm.v, obj.enter)
  if nArgs == 4:
    if SQ_FAILED(get(v, 4, obj.leave)):
      return sq_throwerror(v, "failed to get leave")
    sq_addref(gVm.v, obj.leave)
  gEngine.room.triggers.add(obj)
  0

proc clampInWalkbox(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let numArgs = sq_gettop(v)
  var pos1, pos2: Vec2f
  if numArgs == 3:
    var x = 0
    if SQ_FAILED(get(v, 2, x)):
      return sq_throwerror(v, "failed to get x")
    var y = 0
    if SQ_FAILED(get(v, 3, y)):
      return sq_throwerror(v, "failed to get y")
    pos1 = vec2(x.float32, y.float32)
    pos2 = pos1
  elif numArgs == 5:
    var x1 = 0
    if SQ_FAILED(get(v, 2, x1)):
      return sq_throwerror(v, "failed to get x1")
    var y1 = 0
    if SQ_FAILED(get(v, 3, y1)):
      return sq_throwerror(v, "failed to get y1")
    pos1 = vec2(x1.float32, y1.float32)
    var x2 = 0
    if SQ_FAILED(sq_getinteger(v, 4, x2)):
      return sq_throwerror(v, "failed to get x2")
    var y2 = 0
    if SQ_FAILED(sq_getinteger(v, 5, y1)):
      return sq_throwerror(v, "failed to get y2")
    pos2 = vec2(x2.float32, y2.float32)
  else:
    return sq_throwerror(v, "Invalid argument number in clampInWalkbox")
  let walkboxes = gEngine.room.walkboxes
  for walkbox in walkboxes:
    if walkbox.contains(pos1):
      info fmt"clampInWalkbox({pos1}) -> {pos1}"
      push(v, pos1)
      return 1
  let pos = walkboxes[0].getClosestPointOnEdge(pos2)
  info fmt"clampInWalkbox({pos2}) -> {pos}"
  push(v, pos)
  return 1

proc createLight(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var color: int
  if SQ_FAILED(get(v, 2, color)):
    return sq_throwerror(v, "failed to get color")
  var x: int32
  if SQ_FAILED(get(v, 3, x)):
    return sq_throwerror(v, "failed to get x")
  var y: int32
  if SQ_FAILED(get(v, 4, y)):
    return sq_throwerror(v, "failed to get y")
  let light = gEngine.room.createLight(rgba(color), vec2(x, y))
  info fmt"createLight({color}) -> {light.id}"
  push(v, light.id)
  1

proc enableTrigger(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  var enabled: bool
  if SQ_FAILED(get(v, 3, enabled)):
    return sq_throwerror(v, "failed to get enabled")
  if enabled:
    gEngine.room.triggers.add obj
  else:
    let index = gEngine.room.triggers.find obj
    if index != -1:
      gEngine.room.triggers.del index
  0

proc enterRoomFromDoor(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object")
  gEngine.enterRoom(obj.room, obj)
  return 0

proc lightBrightness(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let light = light(v, 2)
  if not light.isNil:
    var brightness: float
    if SQ_FAILED(get(v, 3, brightness)):
      return sq_throwerror(v, "failed to get brightness")
    light.brightness = brightness
  0

proc lightConeDirection(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let light = light(v, 2)
  if not light.isNil:
    var direction: float
    if SQ_FAILED(get(v, 3, direction)):
      return sq_throwerror(v, "failed to get direction")
    light.coneDirection = direction
  0

proc lightConeAngle(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let light = light(v, 2)
  if not light.isNil:
    var angle: float
    if SQ_FAILED(get(v, 3, angle)):
      return sq_throwerror(v, "failed to get angle")
    light.coneAngle = angle
  0

proc lightConeFalloff(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let light = light(v, 2)
  if not light.isNil:
    var falloff: float
    if SQ_FAILED(get(v, 3, falloff)):
      return sq_throwerror(v, "failed to get falloff")
    light.coneFalloff = falloff
  0

proc lightCutOffRadius(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let light = light(v, 2)
  if not light.isNil:
    var cutOffRadius: float
    if SQ_FAILED(get(v, 3, cutOffRadius)):
      return sq_throwerror(v, "failed to get cutOffRadius")
    light.cutOffRadius = cutOffRadius
  0

proc lightHalfRadius(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let light = light(v, 2)
  if not light.isNil:
    var halfRadius: float
    if SQ_FAILED(get(v, 3, halfRadius)):
      return sq_throwerror(v, "failed to get halfRadius")
    light.halfRadius = halfRadius
  0

proc lightTurnOn(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let light = light(v, 2)
  if not light.isNil:
    var on: bool
    if SQ_FAILED(get(v, 3, on)):
      return sq_throwerror(v, "failed to get on")

    light.on = on
  0

proc lightZRange(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let light = light(v, 2)
  if not light.isNil:
    var nearY, farY: int
    if SQ_FAILED(get(v, 3, nearY)):
      return sq_throwerror(v, "failed to get nearY")
    if SQ_FAILED(get(v, 4, farY)):
      return sq_throwerror(v, "failed to get farY")
    warn "lightZRange not implemented"
  0

proc defineRoom(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## This command is used during the game's boot process. 
  ## `defineRoom` is called once for every room in the game, passing it the room's room object.
  ## If the room has not been defined, it can not be referenced. 
  ## `defineRoom` is typically called in the the DefineRooms.nut file which loads and defines every room in the game. 
  var table: HSQOBJECT
  sq_resetobject(table)
  if SQ_FAILED(sq_getstackobj(v, 2, table)):
    return sq_throwerror(v, "failed to get room table")
  var name: string
  v.getf(table, "name", name)
  if name.len == 0:
    v.getf(table, "background", name)
  let room = defineRoom(name, table)
  info fmt"Define room: {name}"
  gEngine.rooms.add room
  push(v, room.table)
  1

proc definePseudoRoom(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Creates a new room called name using the specified template. 
  ## 
  ## . code-block:: Squirrel
  ## for (local room_id = 1; room_id <= HOTEL_ROOMS_PER_FLOOR; room_id++) {
  ##     local room = definePseudoRoom("HotelRoomA"+((floor_id*100)+room_id), HotelRoomA)
  ##     local door = floor["hotelHallDoor"+room_id]
  ##     ...
  ## }
  var name: string
  if SQ_FAILED(get(v, 2, name)):
    return sq_throwerror(v, "failed to get name")
  var table: HSQOBJECT
  sq_resetobject(table)
  # if this is a pseudo room, we have to clone the table
  # to have a different instance by room
  if SQ_FAILED(sq_clone(v, 3)):
    return sq_throwerror(v, "failed to clone room table")
  if SQ_FAILED(sq_getstackobj(v, -1, table)):
    return sq_throwerror(v, "failed to get room table")
  
  let room = defineRoom(name, table, true)
  info fmt"Define pseudo room: {name}"
  gEngine.rooms.add room
  push(v, room.table)
  1

proc findRoom(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns the room table for the room specified by the string roomName.
  ## Useful for returning specific pseudo rooms where the name is composed of text and a variable. 
  ## 
  ## .. code-block:: Squirrel
  ## local standardRoom = findRoom("HotelRoomA"+keycard.room_num)
  var name: string
  if SQ_FAILED(get(v, 2, name)):
    return sq_throwerror(v, "failed to get name")
  for room in gEngine.rooms:
    if room.name == name:
      push(v, room.table)
      return 1
  warn fmt"Room '{name}' not found"
  sq_pushnull(v)
  1

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

proc removeTrigger(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  if sq_gettype(v, 2) == OT_CLOSURE:
    var closure: HSQOBJECT
    sq_resetobject(closure)
    if SQ_FAILED(get(v, 3, closure)):
      return sq_throwerror(v, "failed to get closure")
    for i in 0..<gEngine.room.triggers.len:
      let trigger = gEngine.room.triggers[i]
      if trigger.enter == closure or trigger.leave == closure:
        gEngine.room.triggers.del i
        return 0
  else:
    let obj = obj(v, 2)
    if obj.isNil:
      return sq_throwerror(v, "failed to get object")
    let i = gEngine.room.triggers.find(obj)
    if i != -1:
      info fmt"Remove room trigger: {obj.name}({obj.key})"
      gEngine.room.triggers.del gEngine.room.triggers.find(obj)
    return 0

proc roomActors(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns an array of all the actors in the specified room.
  ## 
  ## .. code-block:: Squirrel
  ## local actorInBookstore = roomActors(BookStore)
  ## if (actorInBookstore.len()>1) { ... }
  ## 
  ## local spotters = roomActors(currentRoom)
  ## foreach(actor in spotters) { ...}
  let room = room(v, 2)
  if room.isNil:
    return sq_throwerror(v, "failed to get room")
  
  sq_newarray(v, 0)
  for actor in gEngine.actors:
    if actor.room == room:
      push(v, actor.table)
      discard sq_arrayappend(v, -2)
  1

proc roomEffect(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var effect = 0
  if SQ_FAILED(get(v, 2, effect)):
    return sq_throwerror(v, "failed to get effect")
  warn "roomEffect not implemented"
  let nArgs = sq_gettop(v)
  if nArgs == 14:
    discard get(v, 3, gShaderParams.iFade)
    discard get(v, 4, gShaderParams.wobbleIntensity)
    discard get(v, 6, gShaderParams.shadows.r)
    discard get(v, 7, gShaderParams.shadows.g)
    discard get(v, 8, gShaderParams.shadows.b)
    discard get(v, 9, gShaderParams.midtones.r)
    discard get(v, 10, gShaderParams.midtones.g)
    discard get(v, 11, gShaderParams.midtones.b)
    discard get(v, 12, gShaderParams.highlights.r)
    discard get(v, 13, gShaderParams.highlights.g)
    discard get(v, 14, gShaderParams.highlights.b)
  gEngine.room.effect = effect.RoomEffect
  0

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
    gEngine.fade = newTween[float](1.0f, 0.0f, t, ikLinear)
  elif fadeType == 1: # FadeOut
    gEngine.fade = newTween[float](0.0f, 1.0f, t, ikLinear)
  0

proc roomLayer(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Makes all layers at the specified zsort value in room visible (YES) or invisible (NO).
  ## It's also currently the only way to affect parallax layers and can be used for minor animation to turn a layer on and off. 
  ## 
  ## .. code-block:: Squirrel
  ## roomLayer(GrateEntry, -2, NO)  // Make lights out layer invisible
  var r = room(v, 2)
  var layer: int32
  var enabled: SQInteger
  if SQ_FAILED(get(v, 3, layer)):
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
  if not room.overlayTo.isNil:
      room.overlayTo.disable()
  room.overlay = rgba(startColor.int)
  if numArgs == 4:
    var endColor: SQInteger
    if SQ_FAILED(sq_getinteger(v, 3, endColor)):
      return sq_throwerror(v, "failed to get endColor")
    var duration: SQFloat
    if SQ_FAILED(sq_getfloat(v, 4, duration)):
      return sq_throwerror(v, "failed to get duration")
    info fmt"start overlay from {rgba(startColor)} to {rgba(endColor)} in {duration}s"
    gEngine.room.overlayTo = newOverlayTo(duration, room, rgba(endColor))
  0

proc roomRotateTo(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var rotation: float
  if SQ_FAILED(get(v, 2, rotation)):
    return sq_throwerror(v, "failed to get rotation")
  gEngine.room.rotateTo = newRotateTo(0.200f, gEngine.room.scene, rotation, ikLinear)
  0

proc roomSize(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var room = room(v, 2)
  if room.isNil:
    return sq_throwerror(v, "failed to get room")
  push(v, room.roomSize)
  1

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
  v.regGblFun(addTrigger, "addTrigger")
  v.regGblFun(clampInWalkbox, "clampInWalkbox")
  v.regGblFun(createLight, "createLight")
  v.regGblFun(defineRoom, "defineRoom")
  v.regGblFun(definePseudoRoom, "definePseudoRoom")
  v.regGblFun(enableTrigger, "enableTrigger")
  v.regGblFun(enterRoomFromDoor, "enterRoomFromDoor")
  v.regGblFun(findRoom, "findRoom")
  v.regGblFun(lightBrightness, "lightBrightness")
  v.regGblFun(lightConeAngle, "lightConeAngle")
  v.regGblFun(lightConeDirection, "lightConeDirection")
  v.regGblFun(lightConeFalloff, "lightConeFalloff")
  v.regGblFun(lightCutOffRadius, "lightCutOffRadius")
  v.regGblFun(lightHalfRadius, "lightHalfRadius")
  v.regGblFun(lightTurnOn, "lightTurnOn")
  v.regGblFun(lightZRange, "lightZRange")
  v.regGblFun(masterRoomArray, "masterRoomArray")
  v.regGblFun(removeTrigger, "removeTrigger")
  v.regGblFun(roomActors, "roomActors")
  v.regGblFun(roomEffect, "roomEffect")
  v.regGblFun(roomFade, "roomFade")
  v.regGblFun(roomLayer, "roomLayer")
  v.regGblFun(roomRotateTo, "roomRotateTo")
  v.regGblFun(roomSize, "roomSize")
  v.regGblFun(roomOverlayColor, "roomOverlayColor")
  v.regGblFun(walkboxHidden, "walkboxHidden")
  
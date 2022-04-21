import std/logging
import std/strformat
import glm
import sqnim
import squtils
import vm
import ../game/engine
import ../game/actor
import ../game/utils
import ../game/room
import ../gfx/color
import ../scenegraph/node

proc getOppositeFacing(facing: Facing): Facing =
  case facing:
  of FACE_FRONT: return FACE_BACK
  of FACE_BACK:return FACE_FRONT
  of FACE_LEFT:return FACE_RIGHT
  of FACE_RIGHT:return FACE_LEFT

proc getFacing(dir: SQInteger, facing: Facing): Facing =
  if dir == 0x10:
    return getOppositeFacing(facing)
  else:
    case dir:
    of 1: FACE_RIGHT
    of 2: FACE_LEFT
    of 4: FACE_FRONT
    of 8: FACE_BACK
    else: 
       FACE_RIGHT

proc getFacingToFaceTo(actor: Object, obj: Object): Facing =
  let d = obj.node.pos - actor.node.pos
  if d.x == 0:
    result = if d.y > 0: FACE_FRONT else: FACE_BACK
  else:
    result = if d.x > 0: FACE_RIGHT else: FACE_LEFT

proc actorAlpha(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets the transparency for an actor's image in [0.0..1.0]
  var actor = obj(v, 2)
  if actor.isNil:
    return sq_throwerror(v, "failed to get actor")
  var alpha: float
  if SQ_FAILED(get(v, 3, alpha)):
    return sq_throwerror(v, "failed to get alpha")
  actor.node.alpha = alpha
  0

proc actorAt(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Moves the specified actor to the room and x, y coordinates specified.
  ## Also makes the actor face to given direction (options are: FACE_FRONT, FACE_BACK, FACE_LEFT, FACE_RIGHT).
  ## If using a spot, moves the player to the spot as specified in a Wimpy file.
  let numArgs = sq_gettop(v)
  case numArgs:
  of 3:
    var actor = actor(v, 2)
    if actor.isNil:
      return sq_throwerror(v, "failed to get actor")
    info fmt"actorAt {actor.name}"
    var spot = obj(v, 3)
    if not spot.isNil:
      let pos = spot.node.pos + spot.usePos
      actor.room = spot.room
      actor.node.pos = pos
      actor.facing = getFacing(spot.useDir.SQInteger, actor.facing)
    else:
      var room = room(v, 3)
      if room.isNil:
        return sq_throwerror(v, "failed to get spot or room")
      actor.room = room
    0
  of 4:
    var actor = actor(v, 2)
    if actor.isNil:
      return sq_throwerror(v, "failed to get actor")
    var x, y: SQInteger
    if SQ_FAILED(sq_getinteger(v, 3, x)):
      return sq_throwerror(v, "failed to get x")
    if SQ_FAILED(sq_getinteger(v, 4, y)):
      return sq_throwerror(v, "failed to get y")
    actor.node.pos = vec2f(x.float32, y.float32)
    0
  of 5, 6:
    var actor = actor(v, 2)
    if actor.isNil:
      return sq_throwerror(v, "failed to get actor")
    var room = room(v, 3)
    if room.isNil:
      return sq_throwerror(v, "failed to get room")
    var x, y: SQInteger
    if SQ_FAILED(sq_getinteger(v, 4, x)):
      return sq_throwerror(v, "failed to get x")
    if SQ_FAILED(sq_getinteger(v, 5, y)):
      return sq_throwerror(v, "failed to get y")
    var dir = 0.SQInteger
    if numArgs == 6 and SQ_FAILED(sq_getinteger(v, 6, dir)):
      return sq_throwerror(v, "failed to get direction")
    actor.node.pos = vec2f(x.float32, y.float32)
    actor.facing = getFacing(dir, actor.facing)
    actor.room = room
    0
  else:
    sq_throwerror(v, "invalid number of arguments")

proc actorColor(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Adjusts the colour of the actor. 
  ## 
  ## . code-block:: Squirrel
  ## actorColor(coroner, 0xc0c0c0)
  var actor = actor(v, 2)
  if actor.isNil:
    return sq_throwerror(v, "failed to get actor")
  var c: SQInteger
  if SQ_FAILED(sq_getinteger(v, 3, c)):
    return sq_throwerror(v, "failed to get color")
  actor.node.color = rgba(c)
  0

proc actorCostume(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets the actor's costume to the (JSON) filename animation file.
  ## If the actor is expected to preform the standard walk, talk, stand, reach animations, they need to exist in the file.
  ## If a sheet is given, this is a sprite sheet containing all the images needed for the animation. 
  var actor = actor(v, 2)
  if actor.isNil:
    return sq_throwerror(v, "failed to get actor")
  
  var name: SQString
  if SQ_FAILED(sq_getstring(v, 3, name)):
    return sq_throwerror(v, "failed to get name")
  
  var sheet: SQString
  discard sq_getstring(v, 4, sheet)
  info fmt"Actor costume {name} {sheet}"
  actor.setCostume($name, $sheet)

proc actorFace(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Makes the actor face a given direction.
  ## Directions are: FACE_FRONT, FACE_BACK, FACE_LEFT, FACE_RIGHT.
  ## Similar to actorTurnTo, but will not animate the change, it will instantly be in the specified direction. 
  var actor = actor(v, 2)
  if actor.isNil:
    return sq_throwerror(v, "failed to get actor")
  let nArgs = sq_gettop(v)
  if nArgs == 2:
    var dir = actor.facing
    push(v, dir.int)
    result = 1
  else:
    if sq_gettype(v, 3) == OT_INTEGER:
      var dir = 0
      if SQ_FAILED(get(v, 3, dir)):
        return sq_throwerror(v, "failed to get direction")
      # FACE_FLIP ?
      if dir == 0x10:
        let facing = actor.facing.flip()
        actor.facing = facing
      else:
        actor.facing = dir.Facing
    else:
      let actor2 = actor(v, 3)
      if actor2.isNil:
        return sq_throwerror(v, "failed to get actor to face to")
      let facing = getFacingToFaceTo(actor, actor2)
      actor.facing = facing
    result = 0

proc actorHidden(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var actor = actor(v, 2)
  if actor.isNil:
    return sq_throwerror(v, "failed to get actor")
  var hidden = 0
  if SQ_FAILED(get(v, 3, hidden)):
    return sq_throwerror(v, "failed to get hidden")
  actor.node.visible = hidden == 0

proc actorShowHideLayer(v: HSQUIRRELVM, visible: bool): SQInteger =
  var actor = actor(v, 2)
  if actor.isNil:
    return sq_throwerror(v, "failed to get actor")
  var layer: string
  if SQ_FAILED(get(v, 3, layer)):
    return sq_throwerror(v, "failed to get layer")
  actor.showLayer(layer, visible)
  0

proc actorHideLayer(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  actorShowHideLayer(v, false)

proc actorShowLayer(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  actorShowHideLayer(v, true)

proc actorLockFacing(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## If a direction is specified: makes the actor face a given direction, which cannot be changed no matter what the player does.
  ## Directions are: FACE_FRONT, FACE_BACK, FACE_LEFT, FACE_RIGHT. 
  ## If "NO" is specified, it removes all locking and allows the actor to change its facing direction based on player input or otherwise. 
  var actor = actor(v, 2)
  if actor.isNil:
    return sq_throwerror(v, "failed to get actor")
  case sq_gettype(v, 3):
  of OT_INTEGER:
    var facing = 0
    if SQ_FAILED(get(v, 3, facing)):
      return sq_throwerror(v, "failed to get facing")
    if facing == 0:
      actor.unlockFacing()
    else:
      let allFacing = facing.Facing
      actor.lockFacing(allFacing, allFacing, allFacing, allFacing)
  of OT_TABLE:
    var obj: HSQOBJECT
    var back = FACE_BACK.int
    var front = FACE_FRONT.int
    var left = FACE_LEFT.int
    var right = FACE_RIGHT.int
    var reset = 0
    discard sq_getstackobj(v, 3, obj)
    getf(v, obj, "back", back)
    getf(v, obj, "front", front)
    getf(v, obj, "left", left)
    getf(v, obj, "right", right)
    getf(v, obj, "reset", reset)
    if reset != 0:
      actor.resetLockFacing()
    else:
      actor.lockFacing(left.Facing, right.Facing, front.Facing, back.Facing)
  else:
    return sq_throwerror(v, "unknown facing type")
  0

proc actorPlayAnimation(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Plays the specified animation from the player's costume JSON filename.
  ## If YES loop the animation. Default is NO.
  var actor = actor(v, 2)
  if actor.isNil:
    return sq_throwerror(v, "failed to get actor")
  var animation = ""
  if SQ_FAILED(get(v, 3, animation)):
    return sq_throwerror(v, "failed to get animation")
  var loop = 0
  if sq_gettop(v) >= 4 and SQ_FAILED(get(v, 4, loop)):
    return sq_throwerror(v, "failed to get loop")
  info fmt"Play anim {actor.name} {animation} loop={loop}"
  # TODO: actor.stopWalking()
  actor.play(animation, loop != 0)
  0

proc actorRenderOffset(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets the rendering offset of the actor to x and y.
  ## 
  ## A rendering offset of 0,0 would cause them to be rendered from the middle of their image.
  ## Actor's are typically adjusted so they are rendered from the middle of the bottom of their feet.
  ## To maintain sanity, it is best if all actors have the same image size and are all adjust the same, but this is not a requirement. 
  var actor = actor(v, 2)
  if actor.isNil:
    return sq_throwerror(v, "failed to get actor")
  var x, y: SQInteger
  if SQ_FAILED(sq_getinteger(v, 3, x)):
    return sq_throwerror(v, "failed to get x")
  if SQ_FAILED(sq_getinteger(v, 4, y)):
    return sq_throwerror(v, "failed to get y")
  actor.node.offset = vec2f(x.float32, y.float32)
  0

proc actorUseWalkboxes(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Specifies whether the actor needs to abide by walkboxes or not.
  ## 
  ## . code-block:: Squirrel
  ## actorUseWalkboxes(coroner, NO)
  var actor = actor(v, 2)
  if actor.isNil:
    return sq_throwerror(v, "failed to get actor")
  var useWalkboxes = 1
  if SQ_FAILED(get(v, 3, useWalkboxes)):
    return sq_throwerror(v, "failed to get useWalkboxes")
  actor.useWalkboxes = useWalkboxes != 0

proc actorVolume(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var actor = actor(v, 2)
  if actor.isNil:
    return sq_throwerror(v, "failed to get actor")
  var volume = 0.0
  if SQ_FAILED(get(v, 3, volume)):
    return sq_throwerror(v, "failed to get volume")
  actor.volume = volume

proc actorWalkSpeed(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets the walk speed of an actor.
  ## 
  ## The numbers are in pixel's per second.
  ## The vertical movement is typically half (or more) than the horizontal movement to simulate depth in the 2D world.
  var actor = actor(v, 2)
  if actor.isNil:
    return sq_throwerror(v, "failed to get actor")
  var x, y: SQInteger
  if SQ_FAILED(sq_getinteger(v, 3, x)):
    return sq_throwerror(v, "failed to get x")
  if SQ_FAILED(sq_getinteger(v, 4, y)):
    return sq_throwerror(v, "failed to get y")
  actor.walkSpeed = vec2f(x.float32, y.float32)
  0

proc actorWalkTo(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let nArgs = sq_gettop(v)
  var actor = actor(v, 2)
  if actor.isNil:
    return sq_throwerror(v, "failed to get actor")
  if nArgs == 3:
    var obj = obj(v, 3)
    if obj.isNil:
      return sq_throwerror(v, "failed to get actor or object")
    else:
      actor.walk(obj.node.pos + obj.usePos) # TODO: toFacing(obj.useDir))
  elif nArgs == 4:
    var x, y: int
    if SQ_FAILED(get(v, 3, x)):
      return sq_throwerror(v, "failed to get x")
    if SQ_FAILED(get(v, 4, y)):
      return sq_throwerror(v, "failed to get y")
    actor.walk(vec2(x.float32, y.float32)) # TODO: toFacing(obj.useDir))
  else:
    return sq_throwerror(v, "invalid number of arguments in actorWalkTo")
  0

proc createActor(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Creates a new actor from a table.
  ## 
  ## An actor is defined in the DefineActors.nut file.
  if sq_gettype(v, 2) != OT_TABLE:
    return sq_throwerror(v, "failed to get a table")
  
  var actor = newActor()
  sq_resetobject(actor.table)
  discard sq_getstackobj(v, 2, actor.table)
  sq_addref(v, actor.table)

  info "Create actor " &  actor.getName()
  actor.node = newNode(actor.name)
  gEngine.actors.add(actor)

  sq_pushobject(v, actor.table)
  1

proc register_actorlib*(v: HSQUIRRELVM) =
  ## Registers the game actor library
  ## 
  ## It adds all the actor functions in the given Squirrel virtual machine.
  v.regGblFun(actorAlpha, "actorAlpha")
  v.regGblFun(actorAt, "actorAt")
  v.regGblFun(actorColor, "actorColor")
  v.regGblFun(actorCostume, "actorCostume")
  v.regGblFun(actorFace, "actorFace")
  v.regGblFun(actorHidden, "actorHidden")
  v.regGblFun(actorHideLayer, "actorHideLayer")
  v.regGblFun(actorLockFacing, "actorLockFacing")
  v.regGblFun(actorPlayAnimation, "actorPlayAnimation")
  v.regGblFun(actorRenderOffset, "actorRenderOffset")
  v.regGblFun(actorShowLayer, "actorShowLayer")
  v.regGblFun(actorUseWalkboxes, "actorUseWalkboxes")
  v.regGblFun(actorVolume, "actorVolume")
  v.regGblFun(actorWalkSpeed, "actorWalkSpeed")
  v.regGblFun(actorWalkTo, "actorWalkTo")
  v.regGblFun(createActor, "createActor")
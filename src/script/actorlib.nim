import std/logging
import std/strformat
import glm
import sqnim
import squtils
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
  actor.renderOffset = vec2f(x.float32, y.float32)
  return 0;

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
  v.regGblFun(actorRenderOffset, "actorRenderOffset")
  v.regGblFun(actorWalkSpeed, "actorWalkSpeed")
  v.regGblFun(createActor, "createActor")
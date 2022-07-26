import std/logging
import std/strformat
import sqnim
import dlgtgt
import ../script/vm
import ../game/engine
import ../game/room
import ../game/actor
import ../game/motors/motor

type
  EngineDialogTarget* = ref object of DialogTarget
  WaitWhile* = ref object of Motor
    cond: string
    tgt: EngineDialogTarget

proc actor(name: string): Object =
  for actor in gEngine.actors:
    if actor.key == name:
      return actor

method say*(self: EngineDialogTarget, actor, text: string): Motor =
  info fmt"say {actor}: {text}"
  var actor = actor(actor)
  if actor.isNil:
    actor = gEngine.actor
  actor.say(@[text], actor.talkColor)
  actor.talking

method waitWhile*(self: EngineDialogTarget, cond: string): Motor =
  result = WaitWhile(tgt: self, cond: cond)
  result.init()

method shutup*(self: EngineDialogTarget) =
  stopTalking()

method execCond*(self: EngineDialogTarget, cond: string): bool =
  # check if the condition corresponds to an actor name
  let actor = actor(cond)
  if not actor.isNil:
    # yes, so we check if the current actor is the given actor name
    let curActor = gEngine.actor
    result = not curActor.isNil and curActor.key == actor.key
  else:
    var condResult: int
    let top = sq_gettop(gVm.v)
    # compile
    sq_pushroottable(gVm.v)
    let code = "return " & cond
    if SQ_FAILED(sq_compilebuffer(gVm.v, code, code.len, "condition", SQTrue)):
      error fmt"Error executing code {code}"
    else:
      sq_push(gVm.v, -2)
      # call
      if SQ_FAILED(sq_call(gVm.v, 1, SQTrue, SQTrue)):
        error fmt"Error calling code {code}"
      else:
        discard sq_getinteger(gVm.v, -1, condResult)
        result = condResult != 0
        sq_settop(gVm.v, top)

method update*(self: WaitWhile, el: float) =
  if not self.tgt.execCond(self.cond):
    self.disable()
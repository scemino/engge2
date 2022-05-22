import std/logging
import std/strformat
import motor
import ../actor
import ../room

const
  frameDuration = 1.0 / 7.0

type TurnTo = ref object of Motor
  actor: Object
  facings: seq[Facing]
  index: int
  elapsed: float

proc getAnims(src, dst: Facing): seq[Facing] =
  case src:
  of FACE_FRONT:
    case dst:
    of FACE_FRONT:
      return @[]
    of FACE_BACK:
      return @[FACE_LEFT, FACE_BACK]
    of FACE_LEFT:
      return @[FACE_LEFT]
    of FACE_RIGHT:
      return @[FACE_RIGHT]
  of FACE_BACK:
    case dst:
    of FACE_FRONT:
      return @[FACE_LEFT, FACE_FRONT]
    of FACE_BACK:
      return @[]
    of FACE_LEFT:
      return @[FACE_LEFT]
    of FACE_RIGHT:
      return @[FACE_RIGHT]
  of FACE_LEFT:
    case dst:
    of FACE_FRONT:
      return @[FACE_FRONT]
    of FACE_BACK:
      return @[FACE_BACK]
    of FACE_LEFT:
      return @[]
    of FACE_RIGHT:
      return @[FACE_FRONT, FACE_RIGHT]
  of FACE_RIGHT:
    case dst:
    of FACE_FRONT:
      return @[FACE_FRONT]
    of FACE_BACK:
      return @[FACE_BACK]
    of FACE_LEFT:
      return @[FACE_FRONT, FACE_LEFT]
    of FACE_RIGHT:
      return @[]

proc newTurnTo*(actor: Object, dstFacing: Facing): TurnTo =
  result = TurnTo(actor: actor, facings: getAnims(actor.facing, dstFacing))
  result.init()
  info fmt"Actor {actor.name} turn to {result.facings}"

method update(self: TurnTo, el: float) =
  self.elapsed += el
  if self.elapsed > frameDuration:
    self.elapsed -= frameDuration
    if self.index >= self.facings.len:
      self.disable()
    else:
      self.actor.setFacing(self.facings[self.index])
    self.index += 1

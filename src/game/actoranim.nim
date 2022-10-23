import std/tables
import std/strformat
import room
import motors/motor

const
  StandAnimName* = "stand"
  HeadAnimName*  = "head"
  WalkAnimName*  = "walk"
  ReachAnimName* = "reach"

proc getAnimName*(self: Object, key: string): string =
  if self.animNames.contains(key):
    result = self.animNames[key]
  else:
    result = key

proc stand*(self: Object) =
  self.play(self.getAnimName(StandAnimName))

proc setHeadIndex*(self: Object, head: int) =
  for i in 1..6:
    self.showLayer(fmt"{self.getAnimName(HeadAnimName)}{i}", i == head)

proc isWalking*(self: Object): bool =
  not self.walkTo.isNil and self.walkTo.enabled()

proc setAnimationNames*(self: Object, head, stand, walk, reach: string) =
  if head.len > 0:
    self.setHeadIndex(0)
    self.animNames[HeadAnimName] = head
    self.showLayer(self.animNames[HeadAnimName], true)
    self.setHeadIndex(1)
  if stand.len > 0:
    self.animNames[StandAnimName] = stand
  if walk.len > 0:
    self.animNames[WalkAnimName] = walk
  if reach.len > 0:
    self.animNames[ReachAnimName] = reach
  if self.isWalking():
    self.play(self.getAnimName(WalkAnimName), true)
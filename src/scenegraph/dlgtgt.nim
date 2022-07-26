import ../game/motors/motor
import ../gfx/color

type
  DialogTarget* = ref object of RootObj

method actorColor*(self: DialogTarget, actor: string): Color {.base.} =
  discard

method actorColorHover*(self: DialogTarget, actor: string): Color {.base.} =
  discard

method say*(self: DialogTarget, actor, text: string): Motor {.base.} =
  discard

method waitWhile*(self: DialogTarget, cond: string): Motor {.base.} =
  discard

method shutup*(self: DialogTarget) {.base.} =
  discard

method pause*(self: DialogTarget, time: float): Motor {.base.} =
  discard

method execCond*(self: DialogTarget, cond: string): bool {.base.} =
  discard

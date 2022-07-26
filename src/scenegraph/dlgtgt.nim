import ../game/motors/motor

type
  DialogTarget* = ref object of RootObj

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

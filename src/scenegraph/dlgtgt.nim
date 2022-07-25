import ../game/motors/motor

type
  DialogTarget* = ref object of RootObj

method say*(self: DialogTarget, actor, text: string): Motor {.base.} =
  discard

method execCond*(self: DialogTarget, cond: string): bool {.base.} =
  discard

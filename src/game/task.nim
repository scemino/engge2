type Task* = ref object of RootObj
  name*: string

method update*(self: Task, elapsed: float): bool {.base.} =
  discard

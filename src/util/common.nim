proc hasFlag*(i: int, flags: int): bool =
  (i and flags) == flags

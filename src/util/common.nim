proc hasFlag*(i: int, flags: int): bool =
  (i and flags) != 0

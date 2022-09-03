proc hasFlag*(i: int, flags: int): bool =
  (i and flags) == flags

iterator ritems*[T](a: openArray[T]): T =
  var i = high(a)
  while i >= 0:
    yield a[i]
    dec i

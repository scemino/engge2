proc linear*(t: float): float = t

proc easeIn*(t: float): float = t * t * t * t

proc easeOut*(t: float): float =
  let f = (t - 1.0)
  f * f * f * (1.0 - t) + 1.0

proc  easeInOut*(t: float): float =
  if t < 0.5:
    return 8.0 * t * t * t * t
  let f = (t - 1.0)
  -8 * f * f * f * f + 1

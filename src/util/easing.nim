type easing_func* = proc (t: float): float

type InterpolationMethod* = enum
  imLinear = 0
  imEaseIn = 1
  imEaseInOut = 2
  imEaseOut = 3
  imSlowEaseIn = 4
  imSlowEaseOut = 5
  imLooping = 0x10
  imSwing = 0x20

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

proc easing*(self: InterpolationMethod): easing_func =
  case (self.int and 7).InterpolationMethod:
  of imLinear: linear
  of imEaseIn: easeIn
  of imEaseInOut: easeInOut
  of imEaseOut: easeOut
  of imSlowEaseIn: easeIn
  of imSlowEaseOut: easeOut
  else: linear

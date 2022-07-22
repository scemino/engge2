type easing_func* = proc (t: float): float

type 
  InterpolationKind* = enum
    ikLinear = 0
    ikEaseIn = 1
    ikEaseInOut = 2
    ikEaseOut = 3
    ikSlowEaseIn = 4
    ikSlowEaseOut = 5
  InterpolationMethod* = object
    kind*: InterpolationKind
    loop*: bool
    swing*: bool

converter intToInterpolationKind(value: int): InterpolationKind =
  (value and 0xF).InterpolationKind

converter interpolationKindToInterpolationMethod*(value: InterpolationKind): InterpolationMethod =
  InterpolationMethod(kind: value)

converter intToInterpolationMethod*(value: int): InterpolationMethod =
  let loop = (value and 0x10) != 0
  let swing = (value and 0x20) != 0
  InterpolationMethod(kind: value, loop: loop, swing: swing)
  
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
  case self.kind:
  of ikLinear: linear
  of ikEaseIn: easeIn
  of ikEaseInOut: easeInOut
  of ikEaseOut: easeOut
  of ikSlowEaseIn: easeIn
  of ikSlowEaseOut: easeOut

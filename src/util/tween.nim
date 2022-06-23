import easing

type 
  Tween*[T] = object
    frm, to, delta: T
    elapsed, duration: float # duration in ms
    value: T
    easing: easing_func
    enabled*: bool
    dir_forward: bool
    swing: bool
    loop: bool

proc newTween*[T](frm, to: T, duration: float, im: InterpolationMethod): Tween[T] =
  Tween[T](frm: frm, to: to, delta: to - frm, duration: duration, value: frm, easing: easing(im), enabled: true, swing: (im.int and imSwing.int)==imSwing.int, loop: (im.int and imLooping.int)==imLooping.int, dir_forward: true)

proc running*[T](self: Tween[T]): bool =
  if self.swing or self.loop:
    true
  else:
    self.elapsed < self.duration

proc update*[T](self: var Tween[T], elapsed: float) =
  if self.enabled and self.running:
    self.elapsed += elapsed
    var f = clamp(self.elapsed / self.duration, 0.0, 1.0)
    if not self.dir_forward:
      f = 1.0 - f
    if self.elapsed > self.duration and (self.swing or self.loop):
      self.elapsed = self.elapsed - self.duration
      if self.swing:
        self.dir_forward = not self.dir_forward
    if not self.easing.isNil:
      f = self.easing(f)
      self.value = self.frm + f * self.delta

proc current*[T](self: Tween[T]): T {.inline.} =
  self.value

when isMainModule:
  import easing
  var t = newTween[float](0, 5, 2, imLinear)
  t.update(0.5)
  echo t.current()
  doAssert t.current() == 1.25
  t.update(0.5)
  echo t.current()
  doAssert t.current() == 2.5
  t.update(1)
  echo t.current()
  doAssert t.current() == 5

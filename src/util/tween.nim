type 
  EasingFunc = proc (t: float): float
  Tween*[T] = object
    frm, to, delta: T
    elapsed, duration: float # duration in ms
    value: T
    easing: EasingFunc

proc newTween*[T](frm, to: T, duration: float, easing: EasingFunc): Tween[T] =
  Tween[T](frm: frm, to: to, delta: to - frm, duration: duration, value: frm, easing: easing)

proc update*[T](self: var Tween[T], elapsed: float) =
  self.elapsed += elapsed
  if self.elapsed > self.duration:
    self.elapsed = self.duration
  var f = self.elapsed / self.duration
  if not self.easing.isNil:
    f = self.easing(f)
    self.value = self.frm + f * self.delta

proc current*[T](self: Tween[T]): T {.inline.} =
  self.value

proc running*[T](self: Tween[T]): bool =
  self.elapsed != self.duration

when isMainModule:
  import easing
  var t = newTween[float](0, 5, 2, linear)
  t.update(0.5)
  echo t.current()
  doAssert t.current() == 1.25
  t.update(0.5)
  echo t.current()
  doAssert t.current() == 2.5
  t.update(1)
  echo t.current()
  doAssert t.current() == 5

import glm

type Rect*[T] = object
  arr*: array[4, T]

type Recti* = Rect[int32]
type Rectf* = Rect[float32]

proc rect*[T](x, y, w, h: T): Rect[T] =
  Rect[T](arr: [x, y, w, h])

proc rectf*[T](r: Rect[T]): Rectf =
  Rectf(arr: [r.x.float32, r.y.float32, r.w.float32, r.h.float32])

proc rectFromCenterSize*[T](center, size: Vec2[T]): Rect[T] =
  rect(center.x - cast[T](size.x/2), center.y - cast[T](size.y/2), size.x, size.y)

proc rectFromPositionSize*[T](pos, size: Vec2[T]): Rect[T] =
  rect(pos.x, pos.y, size.x, size.y)

proc x*[T](r: Rect[T]): T = r.arr[0]
proc `x=`*[T](r: var Rect[T], x: T) = r.arr[0] = x
proc y*[T](r: Rect[T]): T = r.arr[1]
proc `y=`*[T](r: var Rect[T], y: T) = r.arr[1] = y
proc w*[T](r: Rect[T]): T = r.arr[2]
proc `w=`*[T](r: var Rect[T], w: T) = r.arr[2] = w
proc h*[T](r: Rect[T]): T = r.arr[3]
proc `h=`*[T](r: var Rect[T], h: T) = r.arr[3] = h

proc `/`*(r: Recti, s: Vec2i): Rectf =
  rect(r.x.float32/s.x.float32, r.y.float32/s.y.float32, r.w.float32/s.x.float32, r.h.float32/s.y.float32)

proc pos*[T](self: Rect[T]): Vec2[T] =
  vec2(self.x, self.y)

proc `pos=`*[T](self: var Rect[T], p: Vec2[T]) =
  self.x = p.x
  self.y = p.y

proc `size=`*[T](self: var Rect[T], p: Vec2[T]) =
  self.w = p.x
  self.h = p.y

proc topLeft*[T](self: Rect[T]): Vec2[T] =
  vec2(self.x, self.y + self.h)

proc topRight*[T](self: Rect[T]): Vec2[T] =
  vec2(self.x + self.w, self.y + self.h)

proc bottomLeft*[T](self: Rect[T]): Vec2[T] =
  vec2(self.x, self.y)

proc bottomRight*[T](self: Rect[T]): Vec2[T] =
  vec2(self.x + self.w, self.y)

proc size*[T](self: Rect[T]): Vec2[T] =
  vec2(self.w, self.h)

proc contains*[T](self: Rect[T], pos: Vec2[T]): bool =
  pos.x >= self.x and pos.x <= (self.x + self.w) and pos.y >= self.y and pos.y <= self.y + self.h

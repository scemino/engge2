# Copyright (c) 2017 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------

import poly_types

type
  Epsilon* = object
    eps: float64

proc initEpsilon*(): Epsilon =
  result.eps = 0.0000000001 # sane default? sure why not

proc epsilon*(self: var Epsilon, v: float64) =
  self.eps = v

proc epsilon*(self: Epsilon): float64 =
  self.eps

proc pointAboveOrOnLine*(self: Epsilon, pt, left, right: PointT): bool =
  let
    Ax = left.x
    Ay = left.y
    Bx = right.x
    By = right.y
    Cx = pt.x
    Cy = pt.y
  result = (Bx - Ax) * (Cy - Ay) - (By - Ay) * (Cx - Ax) >= -self.eps

proc pointBetween*(self: Epsilon, p, left, right: PointT): bool =
  # p must be collinear with left->right
  # returns false if p == left, p == right, or left == right
  let
    d_py_ly = p.y - left.y
    d_rx_lx = right.x - left.x
    d_px_lx = p.x - left.x
    d_ry_ly = right.y - left.y
    dot = d_px_lx * d_rx_lx + d_py_ly * d_ry_ly

  # if `dot` is 0, then `p` == `left` or `left` == `right` (reject)
  # if `dot` is less than 0, then `p` is to the left of `left` (reject)
  if dot < self.eps:
    return false

  let sqlen = d_rx_lx * d_rx_lx + d_ry_ly * d_ry_ly
  # if `dot` > `sqlen`, then `p` is to the right of `right` (reject)
  # therefore, if `dot - sqlen` is greater than 0, then `p` is to the right of `right` (reject)
  if dot - sqlen > -self.eps:
    return false

  result = true

proc pointsSameX*(self: Epsilon, p1, p2: PointT): bool {.inline.} =
  result = abs(p1.x - p2.x) < self.eps

proc pointsSameY*(self: Epsilon, p1, p2: PointT): bool {.inline.} =
  result = abs(p1.y - p2.y) < self.eps

proc pointsSame*(self: Epsilon, p1, p2: PointT): bool {.inline.} =
  result = self.pointsSameX(p1, p2) and self.pointsSameY(p1, p2)

proc pointsCompare*(self: Epsilon, p1, p2: PointT): int =
  # returns -1 if p1 is smaller, 1 if p2 is smaller, 0 if equal
  if self.pointsSameX(p1, p2):
    if self.pointsSameY(p1, p2):
      return 0
    else:
      return if p1.y < p2.y: -1 else: 1

  result = if p1.x < p2.x: -1 else: 1

proc pointsCollinear*(self: Epsilon, pt1, pt2, pt3: PointT): bool =
  # does pt1->pt2->pt3 make a straight line?
  # essentially this is just checking to see if the slope(pt1->pt2) === slope(pt2->pt3)
  # if slopes are equal, then they must be collinear, because they share pt2
  let
    dx1 = pt1.x - pt2.x
    dy1 = pt1.y - pt2.y
    dx2 = pt2.x - pt3.x
    dy2 = pt2.y - pt3.y
  result = abs(dx1 * dy2 - dx2 * dy1) < self.eps

type
  IntersectType* = enum
    NoIntersection
    BeforeFirstPoint
    OnFirstPoint
    BetweenFirstAndSecondPoint
    OnSecondPoint
    AfterSecondPoint

  Intersection* = object
    alongA*: IntersectType
    alongB*: IntersectType
    pt*: PointT

proc linesIntersect*(self: Epsilon, a0, a1, b0, b1: PointT): Intersection =
  # returns false if the lines are coincident (e.g., parallel or on top of each other)
  #
  # returns an object if the lines intersect:
  #   {
  #     pt: [x, y],    where the intersection point is at
  #     alongA: where intersection point is along A,
  #     alongB: where intersection point is along B
  #   }
  #
  #  alongA and alongB will each be one of: -2, -1, 0, 1, 2
  #
  #  with the following meaning:
  #
  #    -2   intersection point is before segment's first point
  #    -1   intersection point is directly on segment's first point
  #     0   intersection point is between segment's first and second points (exclusive)
  #     1   intersection point is directly on segment's second point
  #     2   intersection point is after segment's second point
  let
    adx = a1.x - a0.x
    ady = a1.y - a0.y
    bdx = b1.x - b0.x
    bdy = b1.y - b0.y
    axb = adx * bdy - ady * bdx

  if abs(axb) < self.eps:
    return Intersection(alongA: NoIntersection, alongB: NoIntersection) # lines are coincident

  var
    dx = a0.x - b0.x
    dy = a0.y - b0.y
    A  = (bdx * dy - bdy * dx) / axb
    B  = (adx * dy - ady * dx) / axb

  result.alongA = BetweenFirstAndSecondPoint
  result.alongB = BetweenFirstAndSecondPoint
  result.pt.x = a0.x + A * adx
  result.pt.y = a0.y + A * ady

  # categorize where intersection point is along A and B

  let eps = self.eps
  if A <= -eps: result.alongA = BeforeFirstPoint
  elif A < eps: result.alongA = OnFirstPoint
  elif A - 1 <= -eps: result.alongA = BetweenFirstAndSecondPoint
  elif A - 1 < eps: result.alongA = OnSecondPoint
  else: result.alongA = AfterSecondPoint

  if B <= -eps: result.alongB = BeforeFirstPoint
  elif B < eps: result.alongB = OnFirstPoint
  elif B - 1 <= -eps: result.alongB = BetweenFirstAndSecondPoint
  elif B - 1 < eps:   result.alongB = OnSecondPoint
  else: result.alongB = AfterSecondPoint

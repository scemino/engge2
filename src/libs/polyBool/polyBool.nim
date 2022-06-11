# Copyright (c) 2017 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------

import build_log, epsilon, edge_chainer, intersecter, edge_selector, poly_types

export poly_types

type
  PolyBool* = object
    log: BuildLog
    eps: Epsilon
    api: PolyBoolApi

  Selector = proc(self: PolyBool, combined: Combined): Segments

proc initPolyBool*(): PolyBool =
  result.log = nil
  result.eps = initEpsilon()

proc buildLog*(self: var PolyBool, bl: bool) =
  if bl: self.log = newBuildLog()
  else: self.log = nil

proc buildLog*(self: PolyBool): auto =
  if self.log != nil: result = self.log.log()

# getter/setter for epsilon
proc epsilon*(self: var PolyBool, v: float64) =
  self.eps.epsilon(v)

proc epsilon*(self: var PolyBool): var Epsilon =
  self.eps

# core API
proc initPolygon*(inverted: bool = false): Polygon =
  result.regions = @[]
  result.inverted = inverted

proc addRegion*(self: var Polygon) =
  self.regions.add(newSeq[PointT]())

proc addVertex*(self: var Polygon, v: PointT) =
  self.regions[^1].add v

proc addVertex*(self: var Polygon, x, y: float64) =
  self.regions[^1].add(PointT(x: x, y: y))

proc startPolygon*(self: var PolyBool) =
  self.api = intersecter(true, self.eps, self.log)

proc startRegion*(self: var PolyBool) =
  self.api.startRegion()

proc addVertex*(self: var PolyBool, x, y: float64) =
  self.api.addVertex(x, y)

proc endRegion*(self: var PolyBool) =
  self.api.endRegion()

proc endPolygon*(self: var PolyBool, inverted: bool = false): Segments =
  result.segments = self.api.calculateSegmented(inverted)
  result.inverted = inverted

proc segments*(self: PolyBool, poly: Polygon): Segments =
  var api = intersecter(true, self.eps, self.log)
  for region in poly.regions:
    api.addRegion(region)

  result.segments = api.calculateSegmented(poly.inverted)
  result.inverted = poly.inverted

proc combine*(self: PolyBool, a, b: Segments): Combined =
  var api = intersecter(false, self.eps, self.log)
  result.combined  = api.calculateCombined(a.segments, a.inverted, b.segments, b.inverted)
  result.inverted1 = a.inverted
  result.inverted2 = b.inverted

proc selectUnion*(self: PolyBool, combined: Combined): Segments =
  result.segments = selectUnion(combined.combined, self.log)
  result.inverted = combined.inverted1 or combined.inverted2

proc selectIntersect*(self: PolyBool, combined: Combined): Segments =
  result.segments = selectIntersect(combined.combined, self.log)
  result.inverted = combined.inverted1 and combined.inverted2

proc selectDifference*(self: PolyBool, combined: Combined): Segments =
  result.segments = selectDifference(combined.combined, self.log)
  result.inverted = combined.inverted1 and not combined.inverted2

proc selectDifferenceRev*(self: PolyBool, combined: Combined): Segments =
  result.segments = selectDifferenceRev(combined.combined, self.log)
  result.inverted = not combined.inverted1 and combined.inverted2

proc selectXor*(self: PolyBool, combined: Combined): Segments =
  result.segments = selectXor(combined.combined, self.log)
  result.inverted = combined.inverted1 != combined.inverted2

proc polygon*(self: PolyBool, seg: Segments): Polygon =
  result.regions  = segmentChainer(seg.segments, self.eps, self.log)
  result.inverted = seg.inverted

proc operate(self: PolyBool, poly1, poly2: Polygon, selector: Selector): Polygon =
  var
    seg1 = self.segments(poly1)
    seg2 = self.segments(poly2)
    comb = self.combine(seg1, seg2)
    seg3 = self.selector(comb)

  self.polygon(seg3)

# helper functions for common operations
proc clipUnion*(self: PolyBool, poly1, poly2: Polygon): Polygon =
  self.operate(poly1, poly2, selectUnion)

proc clipIntersect*(self: PolyBool, poly1, poly2: Polygon): Polygon =
  self.operate(poly1, poly2, selectIntersect)

proc clipDifference*(self: PolyBool, poly1, poly2: Polygon): Polygon =
  self.operate(poly1, poly2, selectDifference)

proc clipDifferenceRev*(self: PolyBool, poly1, poly2: Polygon): Polygon =
  self.operate(poly1, poly2, selectDifferenceRev)

proc clipXor*(self: PolyBool, poly1, poly2: Polygon): Polygon =
  self.operate(poly1, poly2, selectXor)

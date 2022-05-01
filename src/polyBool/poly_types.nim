# Copyright (c) 2017 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------

import strutils

type
  PointT* = object
    x*, y*: float64

  EdgeFill* = object
    above*, below*: bool

  Edge* = ref object
    id*: int
    start*, stop*: PointT
    thisFill*: EdgeFill
    thatFill*: EdgeFill

  Edges*   = seq[Edge]
  Region*  = seq[PointT]
  Regions* = seq[Region]

  Polygon* = object
    regions*: Regions
    inverted*: bool

  Segments* = object
    segments*: Edges
    inverted*: bool

  Combined* = object
    combined*: Edges
    inverted1*, inverted2*: bool

proc debug*(seg: Edge) =
  var x = "(id: -1, start: (x: " & seg.start.x.formatFloat(ffDecimal, 3)
  x.add ", y: " & seg.start.y.formatFloat(ffDecimal, 3)
  x.add "), stop: (x: " & seg.stop.x.formatFloat(ffDecimal, 3)
  x.add ", y: " & seg.stop.y.formatFloat(ffDecimal, 3)
  x.add "), thisFill: (above: " & $seg.thisFill.above
  x.add ", below: " & $seg.thisFill.below
  x.add "), thatFill: (above: " & $seg.thatFill.above
  x.add ", below: " & $seg.thatFill.below & "))"
  echo x

proc debug*(p: PointT): string =
  result = "(x: " & p.x.formatFloat(ffDecimal, 3)
  result.add ", y: " & p.y.formatFloat(ffDecimal, 3) & ")"

proc debug*(seg: Segments) {.deprecated.} =
  for s in seg.segments:
    s.debug()

proc debug*(seg: Combined) {.deprecated.} =
  for s in seg.combined:
    s.debug()

proc debug*(poly: Polygon) {.deprecated.} =
  for reg in poly.regions:
    stdout.write "["
    for p in reg:
      stdout.write p.debug()
    echo "]"

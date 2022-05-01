# Copyright (c) 2017 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------

import build_log, epsilon, poly_types

proc indexBuilder(edge: Edge): int =
  result = 0
  if edge.thisFill.above: inc(result, 8)
  if edge.thisFill.below: inc(result, 4)
  if edge.thatFill.above: inc(result, 2)
  if edge.thatFill.below: inc result

proc selectEdge(edges: Edges, selection: array[16, int], buildLog: BuildLog): Edges =
  result = @[]

  for edge in edges:
    let index = edge.indexBuilder()
    if selection[index] != 0:
      # copy the edge to the results, while also calculating the fill status
      var res = Edge()
      res.id = if buildLog != nil: buildLog.edgeId() else: -1
      res.start = edge.start
      res.stop  = edge.stop
      res.thisFill.above = selection[index] == 1  # 1 if filled above
      res.thisFill.below = selection[index] == 2  # 2 if filled below
      res.thatFill.above = false
      res.thatFill.below = false
      result.add res

  if buildLog != nil:
    buildLog.selected(result)

# primary | secondary
proc selectUnion*(edges: Edges, buildLog: BuildLog): Edges =
  # above1 below1 above2 below2    Keep?               Value
  #    0      0      0      0   =>   no                  0
  #    0      0      0      1   =>   yes filled below    2
  #    0      0      1      0   =>   yes filled above    1
  #    0      0      1      1   =>   no                  0
  #    0      1      0      0   =>   yes filled below    2
  #    0      1      0      1   =>   yes filled below    2
  #    0      1      1      0   =>   no                  0
  #    0      1      1      1   =>   no                  0
  #    1      0      0      0   =>   yes filled above    1
  #    1      0      0      1   =>   no                  0
  #    1      0      1      0   =>   yes filled above    1
  #    1      0      1      1   =>   no                  0
  #    1      1      0      0   =>   no                  0
  #    1      1      0      1   =>   no                  0
  #    1      1      1      0   =>   no                  0
  #    1      1      1      1   =>   no                  0
  const selection = [
    0, 2, 1, 0,
    2, 2, 0, 0,
    1, 0, 1, 0,
    0, 0, 0, 0]
  result = selectEdge(edges, selection, buildLog)

# primary & secondary
proc selectIntersect*(edges: Edges, buildLog: BuildLog): Edges =
  # above1 below1 above2 below2    Keep?               Value
  #    0      0      0      0   =>   no                  0
  #    0      0      0      1   =>   no                  0
  #    0      0      1      0   =>   no                  0
  #    0      0      1      1   =>   no                  0
  #    0      1      0      0   =>   no                  0
  #    0      1      0      1   =>   yes filled below    2
  #    0      1      1      0   =>   no                  0
  #    0      1      1      1   =>   yes filled below    2
  #    1      0      0      0   =>   no                  0
  #    1      0      0      1   =>   no                  0
  #    1      0      1      0   =>   yes filled above    1
  #    1      0      1      1   =>   yes filled above    1
  #    1      1      0      0   =>   no                  0
  #    1      1      0      1   =>   yes filled below    2
  #    1      1      1      0   =>   yes filled above    1
  #    1      1      1      1   =>   no                  0
  const selection = [
    0, 0, 0, 0,
    0, 2, 0, 2,
    0, 0, 1, 1,
    0, 2, 1, 0]
  result = selectEdge(edges, selection, buildLog)

# primary - secondary
proc selectDifference*(edges: Edges, buildLog: BuildLog): Edges =
  # above1 below1 above2 below2    Keep?               Value
  #    0      0      0      0   =>   no                  0
  #    0      0      0      1   =>   no                  0
  #    0      0      1      0   =>   no                  0
  #    0      0      1      1   =>   no                  0
  #    0      1      0      0   =>   yes filled below    2
  #    0      1      0      1   =>   no                  0
  #    0      1      1      0   =>   yes filled below    2
  #    0      1      1      1   =>   no                  0
  #    1      0      0      0   =>   yes filled above    1
  #    1      0      0      1   =>   yes filled above    1
  #    1      0      1      0   =>   no                  0
  #    1      0      1      1   =>   no                  0
  #    1      1      0      0   =>   no                  0
  #    1      1      0      1   =>   yes filled above    1
  #    1      1      1      0   =>   yes filled below    2
  #    1      1      1      1   =>   no                  0
  const selection = [
    0, 0, 0, 0,
    2, 0, 2, 0,
    1, 1, 0, 0,
    0, 1, 2, 0]
  result = selectEdge(edges, selection, buildLog)

# secondary - primary
proc selectDifferenceRev*(edges: Edges, buildLog: BuildLog): Edges =
  # above1 below1 above2 below2    Keep?               Value
  #    0      0      0      0   =>   no                  0
  #    0      0      0      1   =>   yes filled below    2
  #    0      0      1      0   =>   yes filled above    1
  #    0      0      1      1   =>   no                  0
  #    0      1      0      0   =>   no                  0
  #    0      1      0      1   =>   no                  0
  #    0      1      1      0   =>   yes filled above    1
  #    0      1      1      1   =>   yes filled above    1
  #    1      0      0      0   =>   no                  0
  #    1      0      0      1   =>   yes filled below    2
  #    1      0      1      0   =>   no                  0
  #    1      0      1      1   =>   yes filled below    2
  #    1      1      0      0   =>   no                  0
  #    1      1      0      1   =>   no                  0
  #    1      1      1      0   =>   no                  0
  #    1      1      1      1   =>   no                  0
  const selection = [
    0, 2, 1, 0,
    0, 0, 1, 1,
    0, 2, 0, 2,
    0, 0, 0, 0]
  result = selectEdge(edges, selection, buildLog)

# primary ^ secondary
proc selectXor*(edges: Edges, buildLog: BuildLog): Edges =
  # above1 below1 above2 below2    Keep?               Value
  #    0      0      0      0   =>   no                  0
  #    0      0      0      1   =>   yes filled below    2
  #    0      0      1      0   =>   yes filled above    1
  #    0      0      1      1   =>   no                  0
  #    0      1      0      0   =>   yes filled below    2
  #    0      1      0      1   =>   no                  0
  #    0      1      1      0   =>   no                  0
  #    0      1      1      1   =>   yes filled above    1
  #    1      0      0      0   =>   yes filled above    1
  #    1      0      0      1   =>   no                  0
  #    1      0      1      0   =>   no                  0
  #    1      0      1      1   =>   yes filled below    2
  #    1      1      0      0   =>   no                  0
  #    1      1      0      1   =>   yes filled above    1
  #    1      1      1      0   =>   yes filled below    2
  #    1      1      1      1   =>   no                  0
  const selection = [
    0, 2, 1, 0,
    2, 0, 0, 1,
    1, 0, 0, 2,
    0, 1, 2, 0]
  result = selectEdge(edges, selection, buildLog)

# Copyright (c) 2017 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------

import linked_list, edge_chainer, epsilon, poly_types, build_log

proc clipperError(msg: string): ref Exception =
  new(result)
  result.msg = msg

type
  PolyBoolApi* = object
    mVertex: int
    mFirst, mLast: PointT
    calculateCombined*: proc(edge1: Edges, inverted1: bool, edge2: Edges, inverted2: bool): Edges
    addRegion*:  proc(region: seq[PointT])
    calculateSegmented*: proc(inverted: bool): Edges
    startRegion*: proc()
    addVertex*: proc(x, y: float64)
    endRegion*: proc()

proc intersecter*(selfIntersection: bool, eps: Epsilon, buildLog: BuildLog): PolyBoolApi =
  # selfIntersection is true/false depending on the phase of the overall algorithm

  # edge creation
  proc newEdge(start, stop: PointT): Edge =
    new(result)
    result.id = if buildLog != nil: buildLog.edgeId() else: -1
    result.start = start
    result.stop = stop
    result.thisFill.above = false
    result.thisFill.below = false
    result.thatFill.above = false
    result.thatFill.below = false

  proc copyEdge(start, stop: PointT, seg: Edge): Edge =
    new(result)
    result.id = if buildLog != nil: buildLog.edgeId() else: -1
    result.start = start
    result.stop = stop
    result.thisFill = seg.thisFill
    result.thatFill.above = false
    result.thatFill.below = false    

  # event logic
  var eventRoot = initLinkedList[NodeData]()

  proc eventCompare(p1_isStart: bool, p1_1, p1_2: PointT, p2_isStart: bool, p2_1, p2_2: PointT): int =
    # compare the selected points first
    var comp = eps.pointsCompare(p1_1, p2_1)
    if comp != 0:
      return comp
    # the selected points are the same

    if eps.pointsSame(p1_2, p2_2): # if the non-selected points are the same too...
      return 0 # then the edges are equal

    if p1_isStart != p2_isStart: # if one is a start and the other isn't...
      return if p1_isStart: 1 else: -1 # favor the one that isn't the start

    # otherwise, we'll have to calculate which one is below the other manually
    let aboveOrOnLine = eps.pointAboveOrOnLine(p1_2,
      if p2_isStart: p2_1 else: p2_2, # order matters
      if p2_isStart: p2_2 else: p2_1)

    return if aboveOrOnLine: 1 else: -1

  proc eventAdd(ev: Node, otherPt: PointT) =
    proc insert(here: Node): bool =
      # should ev be inserted before here?
      var comp = eventCompare(ev.data.isStart, ev.data.pt, otherPt,
        here.data.isStart, here.data.pt, here.data.other.data.pt)
      result = comp < 0
    eventRoot.insertBefore(ev, insert)

  proc eventAddEdgeStart(seg: Edge, primary: bool): Node =
    var data: NodeData
    data.isStart = true
    data.pt  = seg.start
    data.seg = seg
    data.primary = primary
    data.other = nil
    data.status = nil
    var evStart = newNode(data)
    eventAdd(evStart, seg.stop)
    return evStart

  proc eventAddEdgeEnd(evStart: Node, seg: Edge, primary: bool) =
    var data: NodeData
    data.isStart = false
    data.pt  = seg.stop
    data.seg = seg
    data.primary = primary
    data.other = evStart
    data.status = nil

    var evEnd = newNode(data)
    evStart.data.other = evEnd
    eventAdd(evEnd, evStart.data.pt)

  proc eventAddEdge(seg: Edge, primary: bool): Node =
    var evStart = eventAddEdgeStart(seg, primary)
    eventAddEdgeEnd(evStart, seg, primary)
    evStart

  proc eventUpdateEnd(ev: Node, stop: PointT) =
    # slides an end backwards
    #   (start)------------(end)    to:
    #   (start)---(end)

    if buildLog != nil:
      buildLog.edgeChop(ev.data.seg, stop)

    ev.data.other.remove()
    ev.data.seg.stop = stop
    ev.data.other.data.pt = stop
    eventAdd(ev.data.other, ev.data.pt)

  proc eventDivide(ev: Node, pt: PointT): Node {.discardable} =
    var ns = copyEdge(pt, ev.data.seg.stop, ev.data.seg)
    eventUpdateEnd(ev, pt)
    eventAddEdge(ns, ev.data.primary)

  proc calculateF(primaryPolyInverted, secondaryPolyInverted: bool): Edges =
    # if selfIntersection is true then there is no secondary polygon, so that isn't used

    # status logic
    var statusRoot = initLinkedList[NodeData]()

    proc statusCompare(ev1, ev2: Node): int =
      let
        a1 = ev1.data.seg.start
        a2 = ev1.data.seg.stop
        b1 = ev2.data.seg.start
        b2 = ev2.data.seg.stop

      if eps.pointsCollinear(a1, b1, b2):
        if eps.pointsCollinear(a2, b1, b2):
          return 1#eventCompare(true, a1, a2, true, b1, b2);
        return if eps.pointAboveOrOnLine(a2, b1, b2): 1 else: -1
      result = if eps.pointAboveOrOnLine(a1, b1, b2): 1 else: -1

    proc statusFindSurrounding(ev: Node): Transition[NodeData] =
      proc check(here: Node): bool =
        var comp = statusCompare(ev, here)
        return comp > 0
      statusRoot.findTransition(check)

    proc checkIntersection(ev1, ev2: Node): Node =
      # returns the edge equal to ev1, or false if nothing equal

      let
        seg1 = ev1.data.seg
        seg2 = ev2.data.seg
        a1 = seg1.start
        a2 = seg1.stop
        b1 = seg2.start
        b2 = seg2.stop

      if buildLog != nil:
        buildLog.checkIntersection(seg1, seg2)

      var i = eps.linesIntersect(a1, a2, b1, b2)

      if i.alongA == NoIntersection and i.alongB == NoIntersection:
        # edgess are parallel or coincident

        # if points aren't collinear, then the edges are parallel, so no intersections
        if not eps.pointsCollinear(a1, a2, b1):
          return nil

        # otherwise, edges are on top of each other somehow (aka coincident)

        if eps.pointsSame(a1, b2) or eps.pointsSame(a2, b1):
          return nil # edges touch at endpoints... no intersection

        var a1_equ_b1 = eps.pointsSame(a1, b1)
        var a2_equ_b2 = eps.pointsSame(a2, b2)

        if a1_equ_b1 and a2_equ_b2:
          return ev2 # edges are exactly equal

        var a1_between = not a1_equ_b1 and eps.pointBetween(a1, b1, b2)
        var a2_between = not a2_equ_b2 and eps.pointBetween(a2, b1, b2)

        # handy for debugging:
        # buildLog.log({
        # a1_equ_b1: a1_equ_b1,
        # a2_equ_b2: a2_equ_b2,
        # a1_between: a1_between,
        # a2_between: a2_between
        # });

        if a1_equ_b1:
          if a2_between:
            #  (a1)---(a2)
            #  (b1)----------(b2)
            eventDivide(ev2, a2)
          else:
            #  (a1)----------(a2)
            #  (b1)---(b2)
            eventDivide(ev1, b2)
          return ev2
        elif a1_between:
          if not a2_equ_b2:
            # make a2 equal to b2
            if a2_between:
              #         (a1)---(a2)
              #  (b1)-----------------(b2)
              eventDivide(ev2, a2)
            else:
              #         (a1)----------(a2)
              #  (b1)----------(b2)
              eventDivide(ev1, b2)

          #         (a1)---(a2)
          #  (b1)----------(b2)
          eventDivide(ev2, a1)
      else:
        # otherwise, lines intersect at i.pt, which may or may not be between the endpoints

        # is A divided between its endpoints? (exclusive)
        if i.alongA == BetweenFirstAndSecondPoint:
          if i.alongB == OnFirstPoint: # yes, at exactly b1
            eventDivide(ev1, b1)
          elif i.alongB == BetweenFirstAndSecondPoint: # yes, somewhere between B's endpoints
            eventDivide(ev1, i.pt)
          elif i.alongB == OnSecondPoint: # yes, at exactly b2
            eventDivide(ev1, b2)

        # is B divided between its endpoints? (exclusive)
        if i.alongB == BetweenFirstAndSecondPoint:
          if i.alongA == OnFirstPoint: # yes, at exactly a1
            eventDivide(ev2, a1)
          elif i.alongA == BetweenFirstAndSecondPoint: # yes, somewhere between A's endpoints (exclusive)
            eventDivide(ev2, i.pt)
          elif i.alongA == OnSecondPoint: # yes, at exactly a2
            eventDivide(ev2, a2)
      return nil

    # main event loop
    var edges = newSeq[Edge]()
    while not eventRoot.isEmpty():
      var ev = eventRoot.getHead()

      if buildLog != nil:
        buildLog.vert(ev.data.pt.x)

      if ev.data.isStart:

        if buildLog != nil:
          buildLog.edgeNew(ev.data.seg, ev.data.primary)

        var
          surrounding = statusFindSurrounding(ev)
          above = surrounding.before
          below = surrounding.after

        if buildLog != nil:
          buildLog.tempStatus(
            ev.data.seg,
            if above != nil: above.data.seg else: nil,
            if below != nil: below.data.seg else: nil)

        proc checkBothIntersections(): Node =
          if above != nil:
            var eve = checkIntersection(ev, above)
            if eve != nil: return eve
          if below != nil:
            return checkIntersection(ev, below)
          result = nil

        var eve = checkBothIntersections()
        if eve != nil:
          # ev and eve are equal
          # we'll keep eve and throw away ev

          # merge ev.seg's fill information into eve.seg

          if selfIntersection:
            var toggle: bool # are we a toggling edge?
            if not ev.data.seg.thisFill.below:
              toggle = true
            else:
              toggle = ev.data.seg.thisFill.above != ev.data.seg.thisFill.below

            # merge two edges that belong to the same polygon
            # think of this as sandwiching two edges together, where `eve.seg` is
            # the bottom -- this will cause the above fill flag to toggle
            if toggle:
              eve.data.seg.thisFill.above = not eve.data.seg.thisFill.above
          else:
            # merge two edges that belong to different polygons
            # each edge has distinct knowledge, so no special logic is needed
            # note that this can only happen once per edge in this phase, because we
            # are guaranteed that all self-intersections are gone
            eve.data.seg.thatFill = ev.data.seg.thisFill

          if buildLog != nil:
            buildLog.edgeUpdate(eve.data.seg)

          ev.data.other.remove()
          ev.remove()

        if eventRoot.getHead() != ev:
          # something was inserted before us in the event queue, so loop back around and
          # process it before continuing
          if buildLog != nil:
            buildLog.rewind(ev.data.seg)
          continue

        # calculate fill flags
        if selfIntersection:
          var toggle: bool # are we a toggling edge?
          if not ev.data.seg.thisFill.below: # if we are a new edge...
            toggle = true # then we toggle
          else: # we are a edge that has previous knowledge from a division
            toggle = ev.data.seg.thisFill.above != ev.data.seg.thisFill.below # calculate toggle

          # next, calculate whether we are filled below us
          if below.isNil: # if nothing is below us...
            # we are filled below us if the polygon is inverted
            ev.data.seg.thisFill.below = primaryPolyInverted
          else:
            # otherwise, we know the answer -- it's the same if whatever is below
            # us is filled above it
            ev.data.seg.thisFill.below = below.data.seg.thisFill.above

          # since now we know if we're filled below us, we can calculate whether
          # we're filled above us by applying toggle to whatever is below us
          if toggle:
            ev.data.seg.thisFill.above = not ev.data.seg.thisFill.below
          else:
            ev.data.seg.thisFill.above = ev.data.seg.thisFill.below
        else:
          # now we fill in any missing transition information, 
          # since we are all-knowing at this point

          if not ev.data.seg.thatFill.above and not ev.data.seg.thatFill.below:
            # if we don't have other information, then we need to figure out if we're
            # inside the other polygon
            var inside: bool
            if below.isNil:
              # if nothing is below us, then we're inside if the other polygon is
              # inverted
              inside = if ev.data.primary: secondaryPolyInverted else: primaryPolyInverted
            else: # otherwise, something is below us
              # so copy the below edge's other polygon's above
              if ev.data.primary == below.data.primary:
                inside = below.data.seg.thatFill.above
              else:
                inside = below.data.seg.thisFill.above
            ev.data.seg.thatFill.above = inside
            ev.data.seg.thatFill.below = inside
            
        if buildLog != nil:
          buildLog.status(
            ev.data.seg,
            if above != nil: above.data.seg else: nil,
            if below != nil: below.data.seg else: nil)

        # insert the status and remember it for later removal
        ev.data.other.data.status = surrounding.insert(newNode(ev.data))
      else:
        var st = ev.data.status

        if st == nil:
          raise clipperError("PolyBool: Zero-length edge detected; your epsilon is probably too small or too large")

        # removing the status will create two new adjacent edges, so we'll need to check
        # for those
        if statusRoot.exists(st.prev) and statusRoot.exists(st.next):
          discard checkIntersection(st.prev, st.next)

        if buildLog != nil:
          buildLog.statusRemove(st.data.seg)

        # remove the status
        st.remove()

        # if we've reached this point, we've calculated everything there is to know, so
        # save the edge for reporting
        if not ev.data.primary:
          # make sure `seg.thisFill` actually points to the primary polygon though
          var s = ev.data.seg.thisFill
          ev.data.seg.thisFill = ev.data.seg.thatFill
          ev.data.seg.thatFill = s
        edges.add(ev.data.seg)

      # remove the event and continue
      eventRoot.getHead().remove()

    if buildLog != nil:
      buildLog.done()

    return edges
    
  proc addEdge(pt1, pt2: PointT) =
    var forward = eps.pointsCompare(pt1, pt2)
    if forward == 0: 
      # points are equal, so we have a zero-length edge
      # just skip it
      return

    var seg = newEdge(if forward < 0: pt1 else: pt2, if forward < 0: pt2 else: pt1)
    discard eventAddEdge(seg, true)
      
  # return the appropriate API depending on what we're doing
  if not selfIntersection:
    # performing combination of polygons, so only deal with already-processed edges
    var res: PolyBoolApi
    res.calculateCombined = proc(edge1: Edges, inverted1: bool, edge2: Edges, inverted2: bool): Edges =
      # edgesX come from the self-intersection API, or this API
      # invertedX is whether we treat that list of segments as an inverted polygon or not
      # returns segments that can be used for further operations
      for seg in edge1: discard eventAddEdge(seg, true)
      for seg in edge2: discard eventAddEdge(seg, false)
      calculateF(inverted1, inverted2)
    return res

  # otherwise, performing self-intersection, so deal with regions
  var res: PolyBoolApi
  res.addRegion = proc(region: seq[PointT]) =
    # regions are a list of points:
    #  [ [0, 0], [100, 0], [50, 100] ]
    # you can add multiple regions before running calculate
    var
      pt1: PointT
      pt2 = region[^1]
    for i in 0..<region.len:
      pt1 = pt2
      pt2 = region[i]
      addEdge(pt1, pt2)
    
  res.startRegion = proc() =
    res.mVertex = 0
    
  res.addVertex = proc(x, y: float64) =
    case res.mVertex
    of 0:
      res.mFirst.x = x
      res.mFirst.y = y
      inc res.mVertex
    of 1:
      res.mLast.x = x
      res.mLast.y = y
      inc res.mVertex
      addEdge(res.mFirst, res.mLast)
    else:
      addEdge(res.mLast, PointT(x: x, y: y))
      res.mLast = PointT(x: x, y: y)
      inc res.mVertex
    
  res.endRegion = proc() =
    if res.mVertex >= 2:
      addEdge(res.mLast, res.mFirst)    
    
  res.calculateSegmented = proc(inverted: bool): Edges =
    # is the polygon inverted?
    # returns edges
    calculateF(inverted, false)
  result = res

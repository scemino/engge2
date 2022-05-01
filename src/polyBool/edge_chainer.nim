# Copyright (c) 2017 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------

import epsilon, build_log, poly_types, algorithm, sequtils

type
  Match = ref object
    index: int
    matchesHead: bool
    matchesPt1: bool

  Chain = ref object
    data: seq[PointT]

proc removeHead(chain: Chain) {.inline.} =
  chain.data.delete(0)
  
proc removeTail(chain: Chain) {.inline.} =
  discard chain.data.pop()
  
proc addHead(chain: Chain, pt: PointT) {.inline.} =
  chain.data.insert(pt)
  
proc addTail(chain: Chain, pt: PointT) {.inline.} =
  chain.data.add(pt)

proc join(a, b: Chain) {.inline.} =
  a.data = a.data.concat(b.data)
  
proc segmentChainer*(segments: Edges, eps: Epsilon, buildLog: BuildLog): Regions =
  var
    chains  = newSeq[Chain]()
    regions = newSeq[Region]()

  for seg in segments:
    let
      pt1 = seg.start
      pt2 = seg.stop

    if eps.pointsSame(pt1, pt2):
      echo "PolyBool: Warning: Zero-length segment detected; your epsilon is probably too small or too large"
      continue

    if buildLog != nil:
      buildLog.chainStart(seg)

    # search for two chains that this segment matches
    var
      firstMatch  = Match(index: 0, matchesHead: false, matchesPt1: false)
      secondMatch = Match(index: 0, matchesHead: false, matchesPt1: false)
      nextMatch   = firstMatch

    proc setMatch(index: int, matchesHead, matchesPt1: bool): bool =
      # return true if we've matched twice
      nextMatch.index = index
      nextMatch.matchesHead = matchesHead
      nextMatch.matchesPt1 = matchesPt1
      if nextMatch == firstMatch:
        nextMatch = secondMatch
        return false
      nextMatch = nil
      result = true # we've matched twice, we're done here

    for i in 0..<chains.len:
      var
        chain = chains[i]
        head  = chain.data[0]
        tail  = chain.data[^1]

      if eps.pointsSame(head, pt1):
        if setMatch(i, true, true): break
      elif eps.pointsSame(head, pt2):
        if setMatch(i, true, false): break
      elif eps.pointsSame(tail, pt1):
        if setMatch(i, false, true): break
      elif eps.pointsSame(tail, pt2):
        if setMatch(i, false, false): break

    if nextMatch == firstMatch:
      # we didn't match anything, so create a new chain
      chains.add(Chain(data: @[pt1, pt2]))
      if buildLog != nil:
        buildLog.chainNew(pt1, pt2)
      continue

    if nextMatch == secondMatch:
      # we matched a single chain

      if buildLog != nil:
        buildLog.chainMatch(firstMatch.index)

      # add the other point to the apporpriate end, and check to see if we've closed the
      # chain into a loop

      var
        index = firstMatch.index
        pt    = if firstMatch.matchesPt1: pt2 else: pt1 # if we matched pt1, then we add pt2, etc
        addToHead = firstMatch.matchesHead # if we matched at head, then add to the head
        chain = chains[index]
        grow  = if addToHead: chain.data[0] else: chain.data[^1]
        grow2 = if addToHead: chain.data[1] else: chain.data[^2]
        oppo  = if addToHead: chain.data[^1] else: chain.data[0]
        oppo2 = if addToHead: chain.data[^2] else: chain.data[1]

      if eps.pointsCollinear(grow2, grow, pt):
        # grow isn't needed because it's directly between grow2 and pt:
        # grow2 ---grow---> pt
        if addToHead:
          if buildLog != nil:
            buildLog.chainRemoveHead(firstMatch.index, pt)
          chain.removeHead()
        else:
          if buildLog != nil:
            buildLog.chainRemoveTail(firstMatch.index, pt)
          chain.removeTail()
        grow = grow2 # old grow is gone... new grow is what grow2 was
      if eps.pointsSame(oppo, pt):
        # we're closing the loop, so remove chain from chains
        chains.delete(index)

        if eps.pointsCollinear(oppo2, oppo, grow):
          # oppo isn't needed because it's directly between oppo2 and grow:
          # oppo2 ---oppo--->grow
          if addToHead:
            if buildLog != nil:
              buildLog.chainRemoveTail(firstMatch.index, grow)
            chain.removeTail()
          else:
            if buildLog != nil:
              buildLog.chainRemoveHead(firstMatch.index, grow)
            chain.removeHead()

        if buildLog != nil:
          buildLog.chainClose(firstMatch.index)

        # we have a closed chain!
        regions.add(chain.data)
        continue

      # not closing a loop, so just add it to the appropriate side
      if addToHead:
        if buildLog != nil:
          buildLog.chainAddHead(firstMatch.index, pt)
        chain.addHead(pt)
      else:
        if buildLog != nil:
          buildLog.chainAddTail(firstMatch.index, pt)
        chain.addTail(pt)
      continue

    # otherwise, we matched two chains, so we need to combine those chains together

    proc reverseChain(index: int) =
      if buildLog != nil:
        buildLog.chainReverse(index)
      chains[index].data.reverse() # gee, that's easy

    proc appendChain(index1, index2: int) =
      # index1 gets index2 appended to it, and index2 is removed
      var
        chain1 = chains[index1]
        chain2 = chains[index2]
        tail  = chain1.data[^1]
        tail2 = chain1.data[^2]
        head  = chain2.data[0]
        head2 = chain2.data[1]

      if eps.pointsCollinear(tail2, tail, head):
        # tail isn't needed because it's directly between tail2 and head
        # tail2 ---tail---> head
        if buildLog != nil:
          buildLog.chainRemoveTail(index1, tail)
        chain1.removeTail()
        tail = tail2 # old tail is gone... new tail is what tail2 was

      if eps.pointsCollinear(tail, head, head2):
        # head isn't needed because it's directly between tail and head2
        # tail ---head---> head2
        if buildLog != nil:
          buildLog.chainRemoveHead(index2, head)
        chain2.removeHead()

      if buildLog != nil:
        buildLog.chainJoin(index1, index2)
      chains[index1].join(chain2)
      chains.delete(index2)

    var F = firstMatch.index
    var S = secondMatch.index

    if buildLog != nil:
      buildLog.chainConnect(F, S)

    var reverseF = chains[F].data.len < chains[S].data.len # reverse the shorter chain, if needed
    if firstMatch.matchesHead:
      if secondMatch.matchesHead:
        if reverseF:
          # <<<< F <<<< --- >>>> S >>>>
          reverseChain(F)
          # >>>> F >>>> --- >>>> S >>>>
          appendChain(F, S)
        else:
          # <<<< F <<<< --- >>>> S >>>>
          reverseChain(S)
          # <<<< F <<<< --- <<<< S <<<<   logically same as:
          # >>>> S >>>> --- >>>> F >>>>
          appendChain(S, F)
      else:
        # <<<< F <<<< --- <<<< S <<<<   logically same as:
        # >>>> S >>>> --- >>>> F >>>>
        appendChain(S, F)
    else:
      if secondMatch.matchesHead:
        # >>>> F >>>> --- >>>> S >>>>
        appendChain(F, S)
      else:
        if reverseF:
          # >>>> F >>>> --- <<<< S <<<<
          reverseChain(F)
          # <<<< F <<<< --- <<<< S <<<<   logically same as:
          # >>>> S >>>> --- >>>> F >>>>
          appendChain(S, F)
        else:
          # >>>> F >>>> --- <<<< S <<<<
          reverseChain(S)
          # >>>> F >>>> --- >>>> S >>>>
          appendChain(F, S)
  result = regions

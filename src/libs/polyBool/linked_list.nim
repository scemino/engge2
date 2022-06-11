# Copyright (c) 2017 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------

import poly_types

type
  LinkedNode*[T] = ref object
    prev*: LinkedNode[T]
    next*: LinkedNode[T]
    data*: T
    remove*: proc()

  LinkedList*[T] = object
    root: LinkedNode[T]

  CheckProc*[T] = proc(node: LinkedNode[T]): bool

  NodeData* = object
   isStart*: bool
   pt*: PointT
   seg*: Edge
   primary*: bool
   other*: LinkedNode[NodeData]
   status*: LinkedNode[NodeData]

  Node* = LinkedNode[NodeData]

proc initLinkedList*[T](): LinkedList[T] =
  result.root = LinkedNode[T](prev: nil, next: nil)

proc exists*[T](self: LinkedList[T], node: LinkedNode[T]): bool =
  result  = node != nil and node != self.root

proc isEmpty*[T](self: LinkedList[T]): bool =
  result = self.root.next == nil

proc getHead*[T](self: LinkedList[T]): LinkedNode[T] =
  result = self.root.next

proc insertBefore*[T](self: LinkedList[T], node: LinkedNode[T], check: CheckProc[T]) =
  var
    last = self.root
    here = self.root.next

  while here != nil:
    if check(here):
      node.prev = here.prev
      node.next = here
      here.prev.next = node
      here.prev = node
      return
    last = here
    here = here.next

  last.next = node
  node.prev = last
  node.next = nil

type
  InsertProc*[T] = proc(node: LinkedNode[T]): LinkedNode[T]

  Transition*[T] = ref object
    before*: LinkedNode[T]
    after*: LinkedNode[T]
    insert*: InsertProc[T]

proc findTransition*[T](self: LinkedList[T], check: CheckProc[T]): Transition[T] =
  var
    prev = self.root
    here = self.root.next

  while here != nil:
    if check(here):
      break
    prev = here
    here = here.next

  result = new(Transition[T])
  result.before = if prev == self.root: nil else: prev
  result.after  = here
  result.insert = proc(node: LinkedNode[T]): LinkedNode[T] =
    node.prev = prev
    node.next = here
    prev.next = node
    if here != nil:
      here.prev = node
    result = node

proc newNode*[T](data: T): LinkedNode[T] =
  var node = LinkedNode[T](prev: nil, next: nil, data: data)
  node.remove = proc() =
    node.prev.next = node.next
    if node.next != nil:
      node.next.prev = node.prev
    node.prev = nil
    node.next = nil
  result = node
  
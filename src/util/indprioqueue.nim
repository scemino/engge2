type
  IndexedPriorityQueue = ref object of RootObj
    keys: ptr seq[float]
    data: seq[int]

proc newIndexedPriorityQueue*(keys: ptr seq[float]): IndexedPriorityQueue =
  IndexedPriorityQueue(keys: keys)

proc reorderUp*(self: IndexedPriorityQueue) =
  if self.data.len > 0:
    var a = self.data.len - 1
    while a > 0:
      if self.keys[self.data[a]] >= self.keys[self.data[a - 1]]:
        return
      swap(self.data[a], self.data[a - 1])
      a -= 1

proc reorderDown*(self: IndexedPriorityQueue) =
  if self.data.len > 0:
    for a in 0..<self.data.len - 1:
      if self.keys[self.data[a]] > self.keys[self.data[a + 1]]:
        swap(self.data[a], self.data[a + 1])

proc insert*(self: IndexedPriorityQueue, index: int) =
  self.data.add(index)
  self.reorderUp()

proc pop*(self: IndexedPriorityQueue): int =
  result = self.data[0]
  self.data[0] = self.data[^1]
  self.data.del (self.data.len - 1)
  self.reorderDown()

proc len*(self: IndexedPriorityQueue): int = self.data.len
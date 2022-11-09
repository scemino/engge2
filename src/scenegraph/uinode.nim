import node

type UINode* = ref object of Node

method activate*(self: UINode) =
  discard

method deactivate*(self: UINode) =
  discard

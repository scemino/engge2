import node

type UINode* = ref object of Node
  active*: bool

proc uiNode*(self: Node): UINode =
  var node = self
  while not node.isNil:
    if node of UINode:
      return cast[UINode](node)
    node = self.parent

method onActivate(self: UINode) =
  self.active = true

method onDeactivate(self: UINode) =
  self.active = false

proc activate*(self: UINode) =
  self.active = true
  self.onActivate()

proc deactivate*(self: UINode) =
  self.active = false
  self.onDeactivate()
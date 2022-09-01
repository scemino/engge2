import state
import ../../scenegraph/node

type
  DlgState = ref object of State
    parent: Node
    node: Node

proc newDlgState*(parent: Node, node: Node): DlgState =
  DlgState(parent: parent, node: node)

method init*(self: DlgState) =
  self.parent.addChild self.node

method deinit*(self: DlgState) =
  self.node.remove()

method update*(self: DlgState) =
  discard

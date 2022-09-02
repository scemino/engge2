import state
import ../../scenegraph/node
import ../../scenegraph/scene
import ../inputstate

type
  DlgState = ref object of State
    ui: Scene
    node, parent: Node
    mouseState: MouseState

proc newDlgState*(node: Node): DlgState =
  DlgState(ui: newScene(), node: node)

method handleInput*(self: DlgState, mouseState: MouseState) =
  self.mouseState = mouseState

method init*(self: DlgState) =
  self.ui.addChild self.node

method deinit*(self: DlgState) =
  self.node.remove()

method activate*(self: DlgState) =
  self.ui.addChild gInputNode

method deactivate*(self: DlgState) =
  self.mouseState = MouseState()

method update*(self: DlgState, elapsed: float) =
  self.ui.update(elapsed, self.mouseState)
  self.ui.draw()

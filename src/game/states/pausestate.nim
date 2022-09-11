import state
import ../../scenegraph/node
import ../../scenegraph/scene
import ../../scenegraph/pausedlg
import ../inputstate
import ../inputmap
import ../engine
import ../thread
import ../../audio/audio

type
  PauseState = ref object of State
    ui: Scene
    node, parent: Node
    mouseState: MouseState

proc pauseGame(self: Engine) =
  for thread in self.threads:
    thread.suspend()
  self.audio.pauseAll()

proc resumeGame(self: Engine) =
  for thread in self.threads:
    thread.resume()
  self.audio.resumeAll()

proc newPauseState*(): PauseState =
  PauseState(ui: newScene(), node: newPauseDialog())

method handleInput*(self: PauseState, mouseState: MouseState) =
  self.mouseState = mouseState

method init*(self: PauseState) =
  self.ui.addChild self.node

method deinit*(self: PauseState) =
  self.node.remove()

method activate*(self: PauseState) =
  regCmdFunc(GameCommand.PauseGame, proc () = popState(1))
  gEngine.pauseGame()
  self.ui.addChild gInputNode

method deactivate*(self: PauseState) =
  unregCmdFunc(GameCommand.PauseGame)
  gEngine.resumeGame()
  self.mouseState = MouseState()

method update*(self: PauseState, elapsed: float) =
  self.ui.update(elapsed, self.mouseState)
  self.ui.draw()

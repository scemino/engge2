import ../gfx/spritesheet
import ../scenegraph/spritenode
import task

type NodeAnim = ref object of Task
    node: SpriteNode
    frames: seq[SpriteSheetFrame]
    index: int
    elapsed: float
    frameDuration: float
    loop: bool

proc newNodeAnim*(node: SpriteNode, frames: seq[SpriteSheetFrame], fps: float, loop = false): NodeAnim =
  new(result)
  result.node = node
  result.frames = frames
  result.frameDuration = 1.0/fps
  result.loop = loop

method update(self: NodeAnim, el: float): bool =
  if self.frames.len != 0:
    self.elapsed += el
    if self.elapsed > self.frameDuration:
      self.elapsed = 0
      if self.index < self.frames.len - 1:
        self.index += 1
      elif self.loop:
        self.index = 0
      else:
        return true
    self.node.setFrame(self.frames[self.index])
    false
  else:
    true
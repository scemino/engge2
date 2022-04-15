import std/tables
import ../gfx/spritesheet
import ../scenegraph/node
import ../scenegraph/spritenode
import motor
import room
import objanim

type NodeAnim = ref object of Motor
    node: SpriteNode
    frames: seq[SpriteSheetFrame]
    index: int
    elapsed: float
    frameDuration: float
    loop: bool
    layers: seq[NodeAnim]

proc newNodeAnim*(obj: Object, anim: ObjectAnimation; node: Node = nil): NodeAnim =
  var ss = obj.getSpriteSheet()
  var frames: seq[SpriteSheetFrame]
  for frame in anim.frames:
    frames.add(ss.frames[frame])
  var newFps = if anim.fps == 0.0f: 10.0f else: anim.fps

  new(result)
  result.frames = frames
  result.frameDuration = 1.0 / newFps
  result.loop = anim.loop
  result.enabled = true

  var newNode = node
  if node.isNil:
    obj.node.removeAll()
    newNode = obj.node

  if frames.len > 0:
    result.node = newSpriteNode(obj.getTexture(), frames[0])
    newNode.addChild result.node
  
  for layer in anim.layers:
    result.layers.add newNodeAnim(obj, layer, newNode)

method update(self: NodeAnim, el: float) =
  if self.frames.len != 0:
    self.elapsed += el
    if self.elapsed > self.frameDuration:
      self.elapsed = 0
      if self.index < self.frames.len - 1:
        self.index += 1
      elif self.loop:
        self.index = 0
      else:
        self.enabled = false
    self.node.setFrame(self.frames[self.index])
  elif self.layers.len != 0:
    var enabled = false
    for layer in self.layers:
      layer.update(el)
      enabled = enabled or layer.enabled
    self.enabled = enabled
  else:
    self.enabled = false
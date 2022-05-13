import std/tables
import ../../gfx/spritesheet
import ../../scenegraph/node
import ../../scenegraph/spritenode
import motor
import ../room
import ../objanim
import ../../util/glmutil
import ../resmanager

type NodeAnim = ref object of Motor
  node: SpriteNode
  frames: seq[SpriteSheetFrame]
  index: int
  elapsed: float
  frameDuration: float
  loop: bool
  layers: seq[NodeAnim]
  anim: ObjectAnimation
  obj: Object

proc newNodeAnim*(obj: Object, anim: ObjectAnimation; fps = 0.0f; node: Node = nil; loop = false): NodeAnim =
  var ss = obj.getSpriteSheet()
  var frames: seq[SpriteSheetFrame]
  for frame in anim.frames:
    if frame == "null":
      frames.add(SpriteSheetFrame())
    else:
      frames.add(ss.frames[frame])
  var newFps: float32
  if fps != 0.0f:
    newFps = fps.float32
  else:
    newFps = if anim.fps == 0.0f: 10.0f else: anim.fps

  new(result)
  result.obj = obj
  result.anim = anim
  result.frames = frames
  result.frameDuration = 1.0 / newFps
  result.loop = loop or anim.loop
  result.enabled = true

  var newNode = node
  if node.isNil:
    obj.node.removeAll()
    newNode = obj.node

  if frames.len > 0:
    var spNode: SpriteNode
    let ss = obj.getSpriteSheet()
    let frame = frames[0]
    let texture = gResMgr.texture(ss.meta.image)
    spNode = newSpriteNode(texture, frame)

    result.node = spNode
    result.node.flipX = obj.getFacing() == FACE_LEFT
    result.node.name = anim.name
    result.node.visible = not obj.hiddenLayers.contains(anim.name)
    if anim.offsets.len > 0:
      result.node.pos = vec2f(anim.offsets[0])
    newNode.addChild result.node
  
  for layer in anim.layers:
    result.layers.add newNodeAnim(obj, layer, fps, newNode, loop)

proc trigSound(self: NodeAnim) =
  if self.anim.triggers.len > 0:
      var trigger = self.anim.triggers[self.index]
      if trigger.len > 0:
        self.obj.trig(trigger)

method update(self: NodeAnim, el: float) =
  if self.frames.len != 0:
    self.elapsed += el
    if self.elapsed > self.frameDuration:
      self.elapsed = 0
      if self.index < self.frames.len - 1:
        self.index += 1
        self.trigSound()
      elif self.loop:
        self.index = 0
        self.trigSound()
      else:
        self.enabled = false
    self.node.setFrame(self.frames[self.index])
    if self.anim.offsets.len > 0:
      self.node.pos = vec2f(self.anim.offsets[self.index])
  elif self.layers.len != 0:
    var enabled = false
    for layer in self.layers:
      layer.update(el)
      enabled = enabled or layer.enabled
    self.enabled = enabled
  else:
    self.enabled = false
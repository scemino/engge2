import std/tables
import glm
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
  frames: seq[SpriteFrame]
  index: int
  elapsed: float
  frameDuration: float
  loop: bool
  instant: bool
  layers: seq[NodeAnim]
  anim: ObjectAnimation
  obj: Object

proc getFrames(self: Object, frames: seq[string]): seq[SpriteFrame] =
  let ss = self.getSpriteSheet()
  if ss.isNil:
    for frame in frames:
      result.add(newSpriteRawFrame(gResMgr.texture(frame)))
  else:
    let texture = gResMgr.texture(ss.meta.image)
    for frame in frames:
      if frame == "null":
        result.add(newSpritesheetFrame(texture, SpriteSheetFrame()))
      elif not ss.isNil and ss.frameTable.contains(frame):
        result.add(newSpritesheetFrame(texture, ss.frame(frame)))

proc getFps(fps, animFps: float32): float32 =
  if fps != 0.0f:
    result = fps.float32
  else:
    result = if animFps == 0.0f: 10.0f else: animFps

proc newNodeAnim*(obj: Object, anim: ObjectAnimation; fps = 0.0f; node: Node = nil, loop = false, instant = false): NodeAnim =
  let frames = obj.getFrames(anim.frames)

  new(result)
  result.obj = obj
  result.anim = anim
  result.frames = frames
  result.frameDuration = 1.0 / getFps(fps, anim.fps)
  result.loop = loop or anim.loop
  result.instant = instant
  result.init()

  var rootNode = node
  if node.isNil:
    for c in obj.node.children:
      if c.name == "#anim":
        rootNode = c
        rootNode.removeAll()
        break
    if rootNode.isNil:
      rootNode = newNode("#anim")
      obj.node.addChild rootNode

  if frames.len > 0:
    result.node = newSpriteNode(if instant: frames[frames.len-1] else: frames[0])
    result.node.flipX = obj.getFacing() == FACE_LEFT
    result.node.name = anim.name
    if anim.offsets.len > 0:
      result.node.pos = vec2f(anim.offsets[0])
    rootNode.addChild result.node
  
  for layer in anim.layers:
    result.layers.add newNodeAnim(obj, layer, fps, rootNode, loop, instant)

proc trigSound(self: NodeAnim) =
  if self.anim.triggers.len > 0 and self.index < self.anim.triggers.len:
    let trigger = self.anim.triggers[self.index]
    if trigger.len > 0:
      self.obj.trig(trigger)

method update(self: NodeAnim, el: float) =
  if not self.node.isNil:
    self.node.visible = not self.obj.hiddenLayers.contains(self.anim.name)
  if self.instant:
    self.disable()
  elif self.frames.len != 0:
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
        self.disable()
    self.node.setFrame(self.frames[self.index])
    if self.anim.offsets.len > 0:
      var off = self.anim.offsets[self.index]
      if self.node.flipX:
        off.x = -off.x
      self.node.pos = vec2f(off.x.float32, off.y.float32)
  elif self.layers.len != 0:
    var enabled = false
    for layer in self.layers:
      layer.update(el)
      enabled = enabled or layer.enabled()
    if not enabled:
      self.disable()
  else:
    self.disable()
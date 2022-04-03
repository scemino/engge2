import std/json
import std/strformat
import glm
import sqnim
import ../io/ggpackmanager
import nimyggpack
import squtils
import room
import ../gfx/graphics
import ../gfx/image
import ../gfx/texture
import ../gfx/spritesheet
import ../gfx/recti
import ../gfx/color

type Facing* = enum
  FACE_RIGHT = 1
  FACE_LEFT = 2
  FACE_FRONT = 4
  FACE_BACK = 8

type Actor* = ref object of RootObj
  table*: HSQObject
  anims: seq[ObjectAnimation]
  spriteSheet: SpriteSheet
  texture: Texture
  visible*: bool
  animIndex: int
  pos*: Vec2f
  color*: Color
  room*: Room
  facing*: Facing
  renderOffset*: Vec2f
  walkSpeed*: Vec2f

proc newActor*(): Actor =
  Actor(visible: true, color: White, pos: vec2(160.0'f32, 90.0'f32))

proc getName*(self: Actor): string =
  getf(self.table, "name", result)

proc setCostume*(self: Actor, name, sheet: string) =
  let stream = gGGPackMgr.loadStream(name & ".json")
  let json = newGGTableDecoder(stream).hash
  self.anims = parseObjectAnimations(json["animations"])
  var path = if sheet.len == 0: json["sheet"].str else: sheet 
  self.spriteSheet = loadSpriteSheet(path & ".json")
  self.texture = newTexture(newImage(self.spriteSheet.meta.image))

proc layer(self: Actor, name: string): ObjectAnimation =
  let anim = self.anims[self.animIndex]
  for layer in anim.layers:
    if layer.name == name:
      return layer

proc setHeadIndex*(self: Actor, index: int) =
  for i in 1..6:
    self.layer("head" & $i).flags = if i == index: 0 else: 1

proc setState*(self: Actor, name: string) =
  for i in 0..<self.anims.len:
    let anim = self.anims[i]
    if anim.name == name:
      self.animIndex = i
      return

proc setEyes*(self: Actor) =
  self.layer("eyes_left").flags = 0
  self.layer("eyes_right").flags = 1
  self.layer("blink").flags = 1

proc getFrame(self: SpriteSheet, name: string): SpriteSheetFrame =
  for frame in self.frames:
    if frame.name == name:
      return frame

proc draw(self: Actor, anim: ObjectAnimation) =
  if anim.frameIndex >= 0 and anim.frameIndex < anim.frames.len:
    let size = self.spriteSheet.meta.size
    var pos = -cameraPos()
    let name = anim.frames[anim.frameIndex]
    if name != "null":
      try:
        let item = self.spriteSheet.getFrame(name)
        let frame = item.frame
        let off = vec2(
          item.spriteSourceSize.x.float32 - item.sourceSize.x.float32 / 2'f32, 
          item.sourceSize.y.float32 / 2'f32 - item.spriteSourceSize.y.float32 - item.spriteSourceSize.h.float32)
        let objPos = vec2(self.pos.x.float32, self.pos.y.float32)
        gfxDrawSprite(pos + objPos + off, frame / size, self.texture, self.color)
      except:
        quit fmt"Failed to render frame {name} for actor {self.getName()}"

proc draw*(self: Actor) =
  if self.visible and self.anims.len > 0 and self.animIndex >= 0 and self.animIndex < self.anims.len:
      let anim = self.anims[self.animIndex]
      self.draw(anim)
      for layer in anim.layers:
        if layer.flags == 0:
          self.draw(layer)


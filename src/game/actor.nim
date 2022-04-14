import std/json
import glm
import sqnim
import nimyggpack
import room
import ../script/squtils
import ../io/ggpackmanager
import ../gfx/image
import ../gfx/texture
import ../gfx/spritesheet
import ../gfx/color
import objanim

proc newActor*(): Object =
  Object(visible: true, color: White, pos: vec2(160.0'f32, 90.0'f32), zsort: 1)

proc getName*(self: Object): string =
  getf(self.table, "name", result)

proc setCostume*(self: Object, name, sheet: string) =
  let stream = gGGPackMgr.loadStream(name & ".json")
  let json = newGGTableDecoder(stream).hash
  self.anims = parseObjectAnimations(json["animations"])
  var path = if sheet.len == 0: json["sheet"].str else: sheet 
  self.spriteSheet = loadSpriteSheet(path & ".json")
  self.texture = newTexture(newImage(self.spriteSheet.meta.image))

proc layer(self: Object, name: string): ObjectAnimation =
  let anim = self.anims[self.animIndex]
  for layer in anim.layers:
    if layer.name == name:
      return layer

proc setHeadIndex*(self: Object, index: int) =
  for i in 1..6:
    self.layer("head" & $i).flags = if i == index: 0 else: 1

proc setState*(self: Object, name: string) =
  for i in 0..<self.anims.len:
    let anim = self.anims[i]
    if anim.name == name:
      self.animIndex = i
      return


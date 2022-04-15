import std/json
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
  Object()

proc getName*(self: Object): string =
  getf(self.table, "name", result)

proc setCostume*(self: Object, name, sheet: string) =
  let stream = gGGPackMgr.loadStream(name & ".json")
  let json = newGGTableDecoder(stream).hash
  self.anims = parseObjectAnimations(json["animations"])
  var path = if sheet.len == 0: json["sheet"].str else: sheet 
  self.spriteSheet = loadSpriteSheet(path & ".json")
  self.texture = newTexture(newImage(self.spriteSheet.meta.image))


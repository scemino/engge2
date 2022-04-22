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
import objanim
import walkto

proc newActor*(): Object =
  Object(facing: FACE_FRONT)

proc getName*(self: Object): string =
  getf(self.table, "name", result)

proc setCostume*(self: Object, name, sheet: string) =
  let stream = gGGPackMgr.loadStream(name & ".json")
  let json = newGGTableDecoder(stream).hash
  self.anims = parseObjectAnimations(json["animations"])
  var path = if sheet.len == 0: json["sheet"].str else: sheet 
  self.spriteSheet = loadSpriteSheet(path & ".json")
  self.texture = newTexture(newImage(self.spriteSheet.meta.image))
  self.play("stand")

proc stand*(self: Object) =
  self.play("stand")

proc walk*(self: Object, dest: Vec2f) =
  self.walkTo = newWalkTo(self, dest)

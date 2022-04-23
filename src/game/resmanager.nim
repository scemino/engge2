import std/tables
import std/strformat
import std/logging
import ../io/ggpackmanager
import ../gfx/bmfont
import ../gfx/image
import ../gfx/texture
import ../gfx/spritesheet

type
  ResManager* = ref object of RootObj
    ## This is a simple resource manager.
    ## If you request a resource, the first time it will be loaded, then it will be in cache.
    ## TODO: I should implement reference counting to free the resource when not used anymore.
    fonts: Table[string, BmFont]              ## fonts cache
    textures: Table[string, Texture]          ## textures cache
    spritesheets: Table[string, SpriteSheet]  ## SpriteSheets cache

proc newResManager*(): ResManager =
  new(result)

proc loadFont(self: ResManager, fontName: string) =
  var path = fmt"{fontName}.fnt"
  if not gGGPackMgr.assetExists(path):
    path = fmt"{fontName}Font.fnt"
  info fmt"Load font {path}"
  self.fonts[fontName] = parseBmFontFromPack(path)

proc font*(self: ResManager, name: string): BmFont =
  if not self.fonts.contains(name):
    self.loadFont(name)
  self.fonts[name]

proc loadTexture(self: ResManager, name: string) =
  info fmt"Load texture {name}"
  self.textures[name] = newTexture(newImage(name))

proc texture*(self: ResManager, name: string): Texture =
  if not self.textures.contains(name):
    self.loadTexture(name)
  self.textures[name]

proc loadSpritesheet(self: ResManager, name: string) =
  info fmt"Load Spritesheet {name}.json"
  self.spritesheets[name] = loadSpriteSheet(name & ".json")

proc spritesheet*(self: ResManager, name: string): SpriteSheet =
  if not self.spritesheets.contains(name):
    self.loadSpritesheet(name)
  self.spritesheets[name]

var gResMgr*: ResManager
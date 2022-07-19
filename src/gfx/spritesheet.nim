import std/[sequtils, streams, options, tables]
import json
import glm
import recti
import ../io/ggpackmanager
import ../game/prefs

type SpriteSheetFrame* = object
  name*: string
  frame*: Recti
  spriteSourceSize*: Recti
  sourceSize*: Vec2i

type SpriteSheetMetadata = object
  app*: string
  version*: string
  image*: string
  format*: string
  size*: Vec2i
  scale*: string
  smartupdate*: string

type SpriteSheet* = ref object of RootObj
  frameTable*: Table[string, SpriteSheetFrame]
  meta*: SpriteSheetMetadata

proc frame*(self: SpriteSheet, key: string): SpriteSheetFrame =
  self.frameTable[getKey(key)]

proc parseSize(node: JsonNode): Vec2i =
  let w = node["w"].getInt
  let h = node["h"].getInt
  vec2(w.int32, h.int32)

proc parseRect(node: JsonNode): Recti =
  rect(node["x"].getInt.int32, node["y"].getInt.int32, node["w"].getInt.int32, node["h"].getInt.int32)

proc parseFrame(name: string, node: JsonNode): SpriteSheetFrame =
  result.name = name
  result.frame = parseRect(node["frame"])
  result.spriteSourceSize = parseRect(node["spriteSourceSize"])
  result.sourceSize = parseSize(node["sourceSize"])

proc parseSpriteSheetMetadata(node: JsonNode): SpriteSheetMetadata =
  SpriteSheetMetadata(app: node["app"].getStr, version: node["version"].getStr, image: node["image"].getStr, format: node["format"].getStr, size: parseSize(node["size"]), scale: node["scale"].getStr, smartupdate: node["smartupdate"].getStr)

proc parseSpriteSheet*(node: JsonNode): SpriteSheet =
  new(result)
  for k,v in node["frames"]:
    result.frameTable[k] = parseFrame(k, v)  
  result.meta = parseSpriteSheetMetadata(node["meta"])

proc parseSpriteSheet*(buffer: string): SpriteSheet =
  parseSpriteSheet(parseJson(newStringStream(buffer), "input"))

proc loadSpriteSheet*(path: string): SpriteSheet =
  let jObj = parseJson(gGGPackMgr.loadStream(path).readAll)
  result = parseSpriteSheet(jObj)

func first*[T](s: openArray[T], f: proc (item: T): bool): Option[T] =
  for itm in items(s):
    if f(itm):
      return some(itm)

when isMainModule:
  var ss = parseSpriteSheet("""{"frames":{"obj_837":{"frame":{"x":0,"y":0,"w":104,"h":80},"rotated":"false","trimmed":"false","spriteSourceSize":{"x":0,"y":0,"w":104,"h":80},"sourceSize":{"w":104,"h":80}},"obj_838":{"frame":{"x":104,"y":0,"w":64,"h":32},"rotated":"false","trimmed":"false","spriteSourceSize":{"x":0,"y":0,"w":64,"h":32},"sourceSize":{"w":64,"h":32}},"obj_839":{"frame":{"x":168,"y":0,"w":64,"h":32},"rotated":"false","trimmed":"false","spriteSourceSize":{"x":0,"y":0,"w":64,"h":32},"sourceSize":{"w":64,"h":32}},"obj_841":{"frame":{"x":232,"y":0,"w":64,"h":32},"rotated":"false","trimmed":"false","spriteSourceSize":{"x":0,"y":0,"w":64,"h":32},"sourceSize":{"w":64,"h":32}},"pirate1":{"frame":{"x":0,"y":80,"w":320,"h":180},"rotated":"false","trimmed":"false","spriteSourceSize":{"x":0,"y":0,"w":320,"h":180},"sourceSize":{"w":320,"h":180}}},"meta":{"app":"https://www.codeandweb.com/texturepacker","version":"1.0","image":"Pirate1Sheet.png","format":"RGBA8888","size":{"w":320,"h":260},"scale":"1","smartupdate":"$TexturePacker:SmartUpdate:76f935035565169e04e28d71e30e8add:7b85c3ad636601cea26c82c092a69958:c87aa37e540c327d9b6fd133131146ee$"}}""")
  echo ss
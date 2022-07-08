import std/tables
import std/strutils
import std/streams
import glm
import font
import recti
import spritesheet
import ../io/ggpackmanager

type
  GGFont = ref object of Font
    ## Represents a bitmap font from a spritesheet.
    spritesheet: SpriteSheet
    glyphs: Table[int, Glyph]
    lineHeight: int

proc parseGGFont*(stream: Stream, path: string): GGFont =
  new(result)
  result.path = path
  var spritesheet = loadSpriteSheet(path)
  var lineHeight = 0
  for (k,frame) in spritesheet.frames.pairs:
    var glyph: Glyph
    glyph.advance = max(frame.sourceSize.x - frame.spriteSourceSize.topLeft.x - 4, 0)
    glyph.bounds = rect(frame.spriteSourceSize.x, frame.sourceSize.y - frame.spriteSourceSize.h - frame.spriteSourceSize.y, frame.spriteSourceSize.w, frame.spriteSourceSize.h)
    lineHeight = max(lineHeight, frame.spriteSourceSize.y.int)
    glyph.textureRect = frame.frame
    result.glyphs[parseInt(k)] = glyph
  result.lineHeight = lineHeight

proc parseGGFontFromPack*(content, path: string): GGFont =
  let fs = newStringStream(content)
  result = parseGGFont(fs, path)
  fs.close()

proc parseGGFontFromPack*(path: string): GGFont =
  result = parseGGFontFromPack(gGGPackMgr.loadStream(path).readAll, path)

method getLineHeight*(self: GGFont): int =
  self.lineHeight

method getKerning*(self: GGFont, prev, next: char): float32 =
  0f

method getGlyph*(self: GGFont, chr: char): Glyph =
  let key = ord(chr)
  if self.glyphs.hasKey(key):
    result = self.glyphs[key]
  else:
    result = self.glyphs[ord('?')]
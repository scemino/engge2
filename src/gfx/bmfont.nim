import std/parseutils
import std/streams
import recti
import ../io/ggpackmanager

type 
  Char = object
    id*, x*, y*, w*, h*, xoff*, yoff*, xadv*, page, chnl: int
    letter: string
  Glyph* = object
    ## represents a glyph: a part of an image for a specific font character
    advance*: int       ## Offset to move horizontally to the next character.
    bounds*: Recti      ## Bounding rectangle of the glyph, in coordinates relative to the baseline.
    textureRect*: Recti ## Texture coordinates of the glyph inside the font's texture.
  Kerning = object
    first, second, amount: int
  BmFont* = ref object of RootObj
    ## Represents a bitmap font
    path*: string
    lineHeight*, base*, scaleW, scaleH, pages, packed: int
    chars: seq[Char]
    kernings: seq[Kerning]

proc parseBmFont*(stream: Stream, path: string): BmFont =
  new(result)
  result.path = path
  for line in stream.lines:
    var key: string
    var off = parseUntil(line, key,' ')
    case key:
    of "info": discard
    of "common": 
      off += parseUntil(line, key, '=', off + 1) + 1
      while off < line.len:
        case key:
        of "lineHeight":
          off += parseInt(line, result.lineHeight, off + 1) + 1
        of "base":
          off += parseInt(line, result.base, off + 1) + 1
        of "scaleW":
          off += parseInt(line, result.scaleW, off + 1) + 1
        of "scaleH":
          off += parseInt(line, result.scaleH, off + 1) + 1
        of "pages":
          off += parseInt(line, result.pages, off + 1) + 1
        of "packed":
          off += parseInt(line, result.packed, off + 1) + 1
        off += parseUntil(line, key, '=', off + 1) + 1
    of "page":
      var id: int
      var file: string
      off += parseUntil(line, key, '=', off + 1) + 1
      while off < line.len:
        case key:
        of "id":
          off += parseInt(line, id, off + 1) + 1
        of "file":
          off += parseUntil(line, file, '"', off + 2) + 2
        off += parseUntil(line, key, '=', off + 1) + 1
    of "char":
      #char id=32     x=168   y=221   width=0     height=0     xoffset=0     yoffset=19    xadvance=3     page=0 chnl=0 letter="space"
      var id, x, y, w, h, xoff, yoff, xadv, page, chnl: int
      var letter: string
      off += parseUntil(line, key, '=', off + 1) + 2
      while off < line.len:
        case key:
        of "id":
          off += parseInt(line, id, off)
          off += skipWhitespace(line, off)
        of "x":
          off += parseInt(line, x, off)
          off += skipWhitespace(line, off)
        of "y":
          off += parseInt(line, y, off)
          off += skipWhitespace(line, off)
        of "width":
          off += parseInt(line, w, off)
          off += skipWhitespace(line, off)
        of "height":
          off += parseInt(line, h, off)
          off += skipWhitespace(line, off)
        of "xoffset":
          off += parseInt(line, xoff, off)
          off += skipWhitespace(line, off)
        of "yoffset":
          off += parseInt(line, yoff, off)
          off += skipWhitespace(line, off)
        of "xadvance":
          off += parseInt(line, xadv, off)
          off += skipWhitespace(line, off)
        of "page":
          off += parseInt(line, page, off)
          off += skipWhitespace(line, off)
        of "chnl":
          off += parseInt(line, chnl, off)
          off += skipWhitespace(line, off)
        of "letter":
          off += parseUntil(line, letter, '"', off) + 2
        off += parseUntil(line, key, '=', off) + 1
      result.chars.add Char(id: id, x: x, y: y, w: w, h: h, xoff: xoff, yoff: yoff, xadv: xadv, page: page, chnl: chnl, letter: letter)
    of "kernings": 
      #kernings count=118
      discard
    of "kerning": 
      #kerning first=32 second=65 amount=-1
      var first, second, amount: int
      off += parseUntil(line, key, '=', off + 1) + 2
      while off < line.len:
        case key:
        of "first":
          off += parseInt(line, first, off)
          off += skipWhitespace(line, off)
        of "second":
          off += parseInt(line, second, off)
          off += skipWhitespace(line, off)
        of "amount":
          off += parseInt(line, amount, off)
          off += skipWhitespace(line, off)
        off += parseUntil(line, key, '=', off) + 1
      result.kernings.add Kerning(first: first, second: second, amount: amount)
  stream.close()

proc parseBmFontFromPack*(content, path: string): BmFont =
  let fs = newStringStream(content)
  result = parseBmFont(fs, path)
  fs.close()

proc parseBmFontFromPack*(path: string): BmFont =
  result = parseBmFontFromPack(gGGPackMgr.loadStream(path).readAll, path)

proc loadBmFromPack*(path: string): BmFont =
  var stream = newFileStream(path, fmRead)
  result = parseBmFont(stream, path)
  stream.close()

proc getKerning*(self: BmFont, prev, next: char): float32 =
  for kern in self.kernings:
    if kern.first == ord(prev) and kern.second == ord(next):
      return kern.amount.float32

proc getGlyph*(self: BmFont, chr: char): Glyph =
  for c in self.chars:
    if c.id == ord(chr):
      return Glyph(advance: c.xadv, bounds: rect(c.xoff.int32, self.lineHeight.int32 - c.yoff.int32 - c.h.int32, c.w.int32, c.h.int32), textureRect: rect(c.x.int32, c.y.int32, c.w.int32, c.h.int32))

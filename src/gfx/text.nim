import std/os
import std/parseutils
import std/strutils
import glm
import fntfont
import color
import recti
import image
import texture
import graphics

type 
  Text* = ref object of RootObj
    font*: FntFont
    texture*: Texture
    text*: string
    color*: Color
    vertices: seq[Vertex]
    bounds: Rectf
    maxWidth*: float32
  CharInfo = object
    chr: char
    pos: Vec2f
    color*: Color
    glyph: Glyph
  TokenId = enum
    tiWhitespace,
    tiString,
    tiColor,
    tiNewLine,
    tiEnd
  Token = object
    id: TokenId
    startOff, endOff: int
  TokenReader = ref object of RootObj
    text: string
    off: int
  Line = object
    tokens: seq[Token]

proc newTokenReader(text: string): TokenReader =
  TokenReader(text: text)

proc substr*(self: TokenReader, tok: Token): string =
  self.text.substr(tok.startOff, tok.endOff)

proc readChar(self: TokenReader): char =
  result = self.text[self.off]
  self.off += 1

proc readTokenId(self: TokenReader): TokenId =
  if self.off < self.text.len:
    var c = self.readChar()
    case c:
    of '\n':
      tiNewLine
    of '\t', ' ':
      self.off += skipUntil(self.text, {'\n', '\t', '#', ' '}, self.off)
      tiWhitespace
    of '#':
      self.off += 6
      tiColor
    else:
      self.off += skipUntil(self.text, {'\n', '\t', '#', ' '}, self.off)
      tiString
  else:
    tiEnd

proc readToken*(self: TokenReader, token: var Token): bool =
  let start = self.off
  let id = self.readTokenId()
  if id != tiEnd:
    token.id = id
    token.startOff = start
    token.endOff = self.off - 1
    true
  else:
    false

iterator items*(self: TokenReader): Token =
  self.off = 0
  var tok: Token
  while self.readToken(tok):
    yield tok

proc newText*(font: FntFont): Text =
  Text(font: font)

proc normalize(texture: Texture, v: Vec2i): Vec2f =
  var textureSize = vec2(texture.width, texture.height)
  vec2(v.x.float32 / textureSize.x.float32, v.y.float32 / textureSize.y.float32)

proc addGlyphQuad(self: Text, info: CharInfo) =
  ## Add a glyph quad to the vertex array

  var left = info.glyph.bounds.bottomLeft.x.float32
  var top = info.glyph.bounds.bottomLeft.y.float32
  var right = info.glyph.bounds.topRight.x.float32
  var bottom = info.glyph.bounds.topRight.y.float32

  var uv1 = normalize(self.texture, info.glyph.textureRect.bottomLeft)
  var uv2 = normalize(self.texture, info.glyph.textureRect.topRight)

  self.vertices.add Vertex(pos: vec2(info.pos.x + left, info.pos.y + top), color: info.color, texCoords: vec2(uv1.x, uv2.y))
  self.vertices.add Vertex(pos: vec2(info.pos.x + right, info.pos.y + top), color: info.color, texCoords: vec2(uv2.x, uv2.y))
  self.vertices.add Vertex(pos: vec2(info.pos.x + left, info.pos.y + bottom), color: info.color, texCoords: vec2(uv1.x, uv1.y))
  self.vertices.add Vertex(pos: vec2(info.pos.x + left, info.pos.y + bottom), color: info.color, texCoords: vec2(uv1.x, uv1.y))
  self.vertices.add Vertex(pos: vec2(info.pos.x + right, info.pos.y + top), color: info.color, texCoords: vec2(uv2.x, uv2.y))
  self.vertices.add Vertex(pos: vec2(info.pos.x + right, info.pos.y + bottom), color: info.color, texCoords: vec2(uv2.x, uv1.y))

proc width(self: Text, reader: TokenReader, tok: Token): float32 =
  for c in reader.substr(tok):
    result += self.font.getGlyph(c).advance.float32

proc update*(self: Text) =
  var (_, name, _) = splitFile(self.font.path)
  echo "img: " & name & ".png"
  let img = newImage(name & ".png")
  self.texture = newTexture(img)

  # Reset
  self.vertices.setLen 0
  self.bounds = Rectf()
  var color = self.color
  
  # split text by tokens and split tokens by lines
  var lines: seq[Line]
  var line: Line
  var reader = newTokenReader(self.text)
  var x: float32
  for tok in reader:
    let w = self.width(reader, tok)
    if tok.id == tiNewLine or (self.maxWidth > 0 and line.tokens.len > 0 and x + w > self.maxWidth):
      lines.add line
      line.tokens.setLen(0)
      x = 0
    if tok.id != tiNewLine:
      line.tokens.add(tok)
      x += w
  lines.add line

  # create quads for all characters
  let lineHeight = self.font.lineHeight.float32
  var charInfos: seq[CharInfo]
  var y: float32
  for line in lines:
    var x: float32
    for tok in line.tokens:
      if tok.id == tiColor:
        var iColor: int
        discard parseHex(reader.substr(tok), iColor, 1)
        color = rgba(iColor or 0xFF000000'i32)
      else:
        for c in reader.substr(tok):
          let glyph = self.font.getGlyph(c)
          charInfos.add(CharInfo(chr: c, pos: vec2f(x, y), color: color, glyph: glyph))
          x += glyph.advance.float32
    y -= lineHeight

  var maxX, maxY: float32
  for info in charInfos:
    # Add the glyph to the vertices
    self.addGlyphQuad(info)

    # Update the current bounds with the non outlined glyph bounds
    maxX = max(maxX, info.pos.x + info.glyph.bounds.topRight.x.float32)
    maxY = max(maxY, info.pos.y + info.glyph.bounds.topRight.y.float32)
  
proc draw*(self: Text; transf = mat4f(1.0)) =
  if not self.font.isNil:
    self.texture.bindTexture()
    gfxDraw(self.vertices, transf)

when isMainModule:
  let reader = newTokenReader("Thimbleweed #ff0080Park\n #008000is #0020FFan #0020FFawesome #10608Fadventure #8020FFgame")
  for tok in reader.items():
    echo $tok & " " & reader.substr(tok)
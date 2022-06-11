import std/os
import std/parseutils
import glm
import color
import recti
import texture
import font
import ../game/resmanager
import graphics

type
  TextAlignment* = enum
    taLeft,
    taCenter,
    taRight
  Text* = ref object of RootObj
    ## This class allows to render a text.
    ## 
    ## A text can contains color in hexadecimal with this format: #RRGGBB
    font*: Font
    texture*: Texture
    txt: string
    col: Color
    txtAlign: TextAlignment
    vertices: seq[Vertex]
    bnds: Vec2f
    maxW: float32
    quads: seq[Rectf]
    dirty: bool
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
    charInfos: seq[CharInfo]

proc newTokenReader(text: string): TokenReader =
  TokenReader(text: text)

proc substr*(self: TokenReader, tok: Token): string =
  self.text.substr(tok.startOff, tok.endOff)

proc readChar(self: TokenReader): char =
  result = self.text[self.off]
  self.off += 1

proc readTokenId(self: TokenReader): TokenId =
  const Whitespace = {' ', '\t', '\v', '\r', '\l', '\f'}
  if self.off < self.text.len:
    var c = self.readChar()
    case c:
    of '\n':
      tiNewLine
    of '\t', ' ':
      self.off += skipWhile(self.text, Whitespace, self.off)
      tiWhitespace
    of '#':
      self.off += 6
      tiColor
    else:
      self.off += skipUntil(self.text, Whitespace + {'#'}, self.off)
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

proc `text=`*(self: Text, text: string) =
  self.txt = text
  self.dirty = true

proc `text`*(self: Text): string =
  self.txt

proc `color=`*(self: Text, col: Color) =
  self.col = col
  self.dirty = true

proc `color`*(self: Text): Color =
  self.col

proc `maxWidth=`*(self: Text, maxW: float) =
  self.maxW = maxW
  self.dirty = true

proc `maxWidth`*(self: Text): float =
  self.maxW

proc `align=`*(self: Text, align: TextAlignment) =
  self.txtAlign = align
  self.dirty = true

proc `align`*(self: Text): TextAlignment =
  self.txtAlign

proc update*(self: Text)

proc `bounds`*(self: Text): Vec2f =
  self.update()
  self.bnds

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
  if self.dirty:
    self.dirty = false
    var (_, name, _) = splitFile(self.font.path)
    self.texture = gResMgr.texture(name & ".png")

    # Reset
    self.vertices.setLen 0
    self.bnds = Vec2f()
    var color = self.color
    
    # split text by tokens and split tokens by lines
    var lines: seq[Line]
    var line: Line
    var reader = newTokenReader(self.text)
    var x: float32
    for tok in reader:
      # ignore color token width
      let w = if tok.id == tiColor or tok.id == tiNewLine: 0.0f else: self.width(reader, tok)
      # new line if width > maxWidth or newline character
      if tok.id == tiNewLine or (self.maxWidth > 0 and line.tokens.len > 0 and x + w > self.maxWidth):
        lines.add line
        line.tokens.setLen(0)
        x = 0
      if tok.id != tiNewLine:
        if line.tokens.len != 0 or tok.id != tiWhitespace:
          line.tokens.add(tok)
          x += w
    lines.add line

    # create quads for all characters
    var maxW: float32
    let lineHeight = self.font.getLineHeight.float32
    var y = -lineHeight
    for line in lines.mitems:
      var prevChar: char
      var x: float32
      for tok in line.tokens:
        if tok.id == tiColor:
          var iColor: int
          discard parseHex(reader.substr(tok), iColor, 1)
          color = rgba(iColor or 0xFF000000'i32)
        else:
          for c in reader.substr(tok):
            let glyph = self.font.getGlyph(c)
            let kern = self.font.getKerning(prevChar, c)
            prevChar = c
            line.charInfos.add(CharInfo(chr: c, pos: vec2f(x + kern, y), color: color, glyph: glyph))
            # self.quads.add(rect(x, y, glyph.bounds.x.float32 + glyph.bounds.w.float32, lineHeight))
            x += glyph.advance.float32
      self.quads.add(rect(0.0f, y, x, lineHeight))
      maxW = max(maxW, x)
      y -= lineHeight

    # Align text
    if self.align == taRight:
      for i in 0..<lines.len:
        let w = maxW - self.quads[i].w
        for info in lines[i].charInfos.mitems:
          info.pos.x += w
    elif self.align == taCenter:
      for i in 0..<lines.len:
        let w = maxW - self.quads[i].w
        for info in lines[i].charInfos.mitems:
          info.pos.x += w / 2

    # Add the glyphs to the vertices
    for line in lines:
      for info in line.charInfos:
        self.addGlyphQuad(info)
      
    self.bnds = vec2(maxW, lines.len.float32 * self.font.getLineHeight.float32)

# proc drawQuadLine(quad: Rectf, transf: Mat4f) =
#   var vertices = [Vertex(pos: quad.topLeft, color: White),
#     Vertex(pos: quad.topRight, color: White),
#     Vertex(pos: quad.bottomRight, color: White),
#     Vertex(pos: quad.bottomLeft, color: White)]
#   gfxDrawLineLoop(vertices, transf)

proc newText*(font: Font, text: string; align = taCenter; maxWidth = 0.0f; color = White): Text =
  result = Text(font: font, txt: text, txtAlign: align, maxW: maxWidth, col: color, dirty: true)
  result.update()

proc draw*(self: Text; transf = mat4f(1.0)) =
  if not self.font.isNil and self.text.len > 0:
    self.update()
    self.texture.bindTexture()
    gfxDraw(self.vertices, transf)

    # for quad in self.quads:
    #   drawQuadLine(quad, transf)

when isMainModule:
  let reader = newTokenReader("Thimbleweed #ff0080Park\n #008000is #0020FFan #0020FFawesome #10608Fadventure #8020FFgame")
  for tok in reader.items():
    echo $tok & " " & reader.substr(tok)
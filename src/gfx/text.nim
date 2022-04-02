import std/os
import std/parseutils
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

proc update*(self: Text) =
  var (_, name, _) = splitFile(self.font.path)
  echo "img: " & name & ".png"
  let img = newImage(name & ".png")
  self.texture = newTexture(img)

  self.vertices.setLen 0
  self.bounds = Rectf()
  var whitespaceWidth = self.font.getGlyph(' ').advance.float32
  let lineHeight = self.font.lineHeight.float32
  var x, y: float32
  
  # reset to default color
  var color = self.color
  
  # Create one quad for each character
  var prevChar: char
  var charInfos: seq[CharInfo]
  var lastWordIndexSaved = -1
  var lastWordIndex = 0
  
  var i = 0
  while i < self.text.len:
    let curChar = self.text[i]
    # Skip the \r char to avoid weird graphical issues
    if curChar != '\r':
      # Apply the kerning offset
      x += self.font.getKerning(prevChar, curChar)
      prevChar = curChar

      # Handle special characters
      if curChar == ' ' or curChar == '\n' or curChar == '\t' or curChar == '#':
        if self.maxWidth > 0 and x >= self.maxWidth:
          y -= lineHeight
          x = 0
          if lastWordIndexSaved != lastWordIndex:
            #i = lastWordIndex + 1
            lastWordIndexSaved = lastWordIndex + 1
          continue
        case curChar:
        of ' ':
          x += whitespaceWidth
          lastWordIndex = i
        of '\t':
          x += whitespaceWidth * 2
          lastWordIndex = i
        of '\n':
          y -= lineHeight
          lastWordIndex = i
          x = 0
        of '#':
          let strColor = self.text.substr(i + 1, i + 6)
          var colorInt: int
          discard parseHex(strColor, colorInt)
          color = rgba(colorInt or 0xFF000000'i32)
          i += 6
        else:
          discard

        # Next glyph, no need to create a quad for whitespace  
        i += 1
        continue
      
      # Extract the current glyph's description
      charInfos.add CharInfo(chr: curChar, pos: vec2(x, y), color: color)
      let glyph = self.font.getGlyph(curChar)
      charInfos[^1].glyph = glyph;

      # Advance to the next character
      x += glyph.advance.float32
      i += 1
        
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
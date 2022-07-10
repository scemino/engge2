import std/unicode
import recti

type
  Glyph* = object
    ## represents a glyph: a part of an image for a specific font character
    advance*: int       ## Offset to move horizontally to the next character.
    bounds*: Recti      ## Bounding rectangle of the glyph, in coordinates relative to the baseline.
    textureRect*: Recti ## Texture coordinates of the glyph inside the font's texture.

  Font* = ref object of RootObj
    path*: string

method getLineHeight*(self: Font): int {.base.} =
  discard

method getKerning*(self: Font, prev, next: Rune): float32 {.base.} =
  discard

method getGlyph*(self: Font, chr: Rune): Glyph {.base.} =
  discard

import glm
import node
import ../gfx/recti
import ../gfx/texture
import ../gfx/graphics
import ../gfx/spritesheet

type
  SpriteNode* = ref object of Node
    texture: Texture
    rect: Recti
    flipX*: bool
  SpriteFrameKind* = enum
    Spritesheet,
    Raw
  SpriteFrame* = object
    texture*: Texture
    case kind*: SpriteFrameKind
      of Spritesheet:
        frame*: SpriteSheetFrame
      of Raw:
        discard

proc newSpritesheetFrame*(texture: Texture, frame: SpriteSheetFrame): SpriteFrame =
  ## Creates a new `Spritesheet SpriteFrame`.
  result = SpriteFrame(kind: Spritesheet, texture: texture, frame: frame)

proc newSpriteRawFrame*(texture: Texture): SpriteFrame =
  ## Creates a new `Raw SpriteFrame`.
  result = SpriteFrame(kind: Raw, texture: texture)

proc setFrame*(self: SpriteNode, frame: SpriteSheetFrame) =
  self.rect = frame.frame
  self.setSize(vec2(frame.frame.size.x.float32, frame.frame.size.y.float32))
  let x = if self.flipX: -frame.sourceSize.x.float32 / 2f + frame.frame.size.x.float32 + frame.spriteSourceSize.x.float32 else: frame.sourceSize.x.float32 / 2'f32 - frame.spriteSourceSize.x.float32
  let y = frame.sourceSize.y.float32 / 2f - frame.spriteSourceSize.h.float32 - frame.spriteSourceSize.y.float32
  let anchor = vec2(round(x - 0.5f), round(y + 0.5f))
  self.setAnchor(anchor)

proc setTexture*(self: SpriteNode, texture: Texture) =
  self.texture = texture
  let rect = rectFromPositionSize(vec2(0'i32, 0'i32), texture.size())
  self.setFrame(SpriteSheetFrame(frame: rect, spriteSourceSize: rect, sourceSize: texture.size()))

proc setFrame*(self: SpriteNode, frame: SpriteFrame) =
  case frame.kind:
  of Spritesheet:
    self.texture = frame.texture
    self.setFrame(frame.frame)
  of Raw:
    self.setTexture(frame.texture)

proc newSpriteNode*(texture: Texture, frame: SpriteSheetFrame): SpriteNode =
  result = SpriteNode(texture: texture)
  result.init()
  result.setFrame(frame)

proc newSpriteNode*(frame: SpriteFrame): SpriteNode =
  result = SpriteNode(texture: frame.texture)
  result.init()
  result.setFrame(frame)

proc newSpriteNode*(texture: Texture): SpriteNode =
  result = SpriteNode(texture: texture)
  result.init()
  result.rect = rect(0'i32, 0'i32, texture.size.x, texture.size.y)
  result.setSize(vec2f(texture.size))
  result.setAnchorNorm(vec2(0.5f, 0.5f))

method drawCore(self: SpriteNode, transf: Mat4f) =
  gfxDrawSprite(self.rect / self.texture.size, self.texture, self.color, transf, self.flipX)

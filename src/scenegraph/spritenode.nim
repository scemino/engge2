import glm
import node
import ../gfx/recti
import ../gfx/texture
import ../gfx/graphics
import ../gfx/color
import ../gfx/spritesheet

type
  SpriteNode* = ref object of Node
    texture: Texture
    rect: Recti

proc newSpriteNode*(texture: Texture, rect: Recti): SpriteNode =
  result = SpriteNode(scale: vec2(1.0f, 1.0f), texture: texture, rect: rect)
  result.setSize(vec2(rect.size.x.float32, rect.size.y.float32))

proc newSpriteNode*(texture: Texture, frame: SpriteSheetFrame): SpriteNode =
  result = SpriteNode(scale: vec2(1.0f, 1.0f), texture: texture, rect: frame.frame)
  result.setSize(vec2(frame.frame.size.x.float32, frame.frame.size.y.float32))
  var anchor = vec2(
          frame.sourceSize.x.float32 / 2'f32 - frame.spriteSourceSize.x.float32, 
          frame.sourceSize.y.float32 / 2'f32 - frame.spriteSourceSize.h.float32 - frame.spriteSourceSize.y.float32)
  result.setAnchor(anchor)

method drawCore(self: SpriteNode, transf: Mat4f) =
  gfxDrawSprite(self.rect / self.texture.size, self.texture, White, transf)

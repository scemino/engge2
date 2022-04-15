import glm
import node
import ../gfx/spritesheet
import ../gfx/texture
import ../gfx/graphics
import ../gfx/color
import ../gfx/recti

type
  ParallaxNode* = ref object of Node
    parallax: Vec2f
    texture: Texture
    frames: seq[SpriteSheetFrame]

proc newParallaxNode*(texture: Texture, frames: seq[SpriteSheetFrame]): ParallaxNode =
  result = ParallaxNode(scale: vec2(1.0f, 1.0f), texture: texture, frames: frames, visible: true)
  var width = 0.0f
  var height = 0.0f
  for frame in frames:
    width += frame.frame.w.float32
    height = frame.frame.h.float32
  result.setSize(vec2(width, height))

method drawCore(self: ParallaxNode, transf: Mat4f) =
  # TODO: apply parallax ;)
  var t = transf
  for frame in self.frames:
    gfxDrawSprite(frame.frame / self.texture.size, self.texture, White, t)
    t = translate(transf, frame.frame.w.float32, 0.0f, 0.0f)

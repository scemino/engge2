import glm
import node
import ../gfx/spritesheet
import ../gfx/texture
import ../gfx/graphics
import ../gfx/recti

type
  ParallaxNode* = ref object of Node
    parallax: Vec2f
    texture: Texture
    frames: seq[SpriteSheetFrame]

proc newParallaxNode*(parallax: Vec2f, texture: Texture, frames: seq[SpriteSheetFrame]): ParallaxNode =
  result = ParallaxNode(parallax: parallax, texture: texture, frames: frames)
  result.init()
  var width = 0.0f
  var height = 0.0f
  for frame in frames:
    width += frame.frame.w.float32
    height = frame.frame.h.float32
  result.setSize(vec2(width, height))

method transform*(self: ParallaxNode, parentTrans: Mat4f): Mat4f =
  let transf = procCall self.Node.transform(parentTrans)
  let camPos = cameraPos()
  let p = vec2f(-camPos.x * self.parallax.x, -camPos.y * self.parallax.y)
  translate(transf, vec3(p, 0.0f))

method drawCore(self: ParallaxNode, transf: Mat4f) =
  var t = transf
  for frame in self.frames:
    let myTransf = translate(t, vec3f(frame.spriteSourceSize.x.float32, frame.sourceSize.y.float32 - frame.spriteSourceSize.h.float32 - frame.spriteSourceSize.y.float32, 0.0f))
    gfxDrawSprite(frame.frame / self.texture.size, self.texture, self.color, myTransf)
    t = translate(transf, frame.frame.w.float32, 0.0f, 0.0f)

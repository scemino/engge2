import glm
import node
import ../gfx/color
import ../gfx/graphics

type
  OverlayNode* = ref object of Node
    ovlColor*: Color

proc newOverlayNode*(): OverlayNode =
  result = OverlayNode(name: "overlay", ovlColor: Transparent)
  result.init()
  result.zOrder = low(int32)

method drawCore(self: OverlayNode, transf: Mat4f) =
  gfxDrawQuad(vec2f(0), camera(), self.ovlColor)

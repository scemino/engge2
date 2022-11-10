import glm
import node
import ../gfx/text
import ../gfx/color
import ../gfx/recti

type
  TextNode* = ref object of Node
    text*: Text

proc newTextNode*(text: Text): TextNode =
  result = TextNode(text: text)
  result.init()
  result.setSize(text.bounds)

proc updateBounds*(self: TextNode) =
  self.setSize(self.text.bounds)

method colorUpdated(self: TextNode, color: Color) =
  self.text.color = color

method drawCore(self: TextNode, transf: Mat4f) =
  self.text.draw(transf)

method getRect*(self: TextNode): Rectf =
  let size = self.size * self.scale
  rectFromPositionSize(self.absolutePosition() + vec2f(0, -size.y) + vec2f(-size.x, size.y) * self.anchorNorm, size)
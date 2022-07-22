import glm
import node
import ../gfx/text
import ../gfx/color

type
  TextNode* = ref object of Node
    text: Text

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

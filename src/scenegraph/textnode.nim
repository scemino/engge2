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

method updateColor(self: TextNode, color: Color) =
  self.nodeColor = rgbaf(color, self.nodeColor.a)
  self.text.color = self.nodeColor

method drawCore(self: TextNode, transf: Mat4f) =
  self.text.draw(transf)

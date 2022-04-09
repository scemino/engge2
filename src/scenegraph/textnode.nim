import glm
import node
import ../gfx/text

type
  TextNode* = ref object of Node
    text: Text

proc newTextNode*(text: Text): TextNode =
  result = TextNode(scale: vec2(1.0f, 1.0f), text: text)
  result.setSize(text.bounds)

method drawCore(self: TextNode, transf: Mat4f) =
  self.text.draw(transf)

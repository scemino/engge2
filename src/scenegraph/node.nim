import glm
import std/algorithm

type
  Node* = ref object of RootObj
    ## Represents a node in a scene graph.
    name*: string                
    parent*: Node                
    children*: seq[Node]         
    pos*: Vec2f                  
    scale*: Vec2f                
    rotation*: float             
    zOrder*: int
    anchorNorm: Vec2f
    anchor: Vec2f
    size: Vec2f

proc setAnchor*(self: Node, anchor: Vec2f) =
  if self.anchor != anchor:
    self.anchorNorm = anchor / self.size
    self.anchor = anchor

proc setAnchorNorm*(self: Node, anchorNorm: Vec2f) =
  if self.anchorNorm != anchorNorm:
    self.anchorNorm = anchorNorm
    self.anchor = self.size * self.anchorNorm

proc setSize*(self: Node, size: Vec2f) =
  if self.size != size:
    self.size = size
    self.anchor = size * self.anchorNorm

proc localTransform(self: Node): Mat4f =
  ## Gets the location transformation = translation * rotation * scale.
  scale(rotate(translate(mat4(1.0f), vec3(self.pos, 0.0f)), glm.radians(self.rotation), 0.0f, 0.0f, 1.0f), self.scale.x, self.scale.y, 1.0f)

proc transform*(self: Node, parentTrans: Mat4f): Mat4f =
  # Gets the full transformation for this node.
  parentTrans * self.localTransform()

proc absolutePosition(self: Node): Vec2f =
  # Gets the absolute position for this node.
  if self.parent.isNil:
    self.pos
  else:
    self.parent.absolutePosition() + self.pos

method addChild*(self: Node, child: Node) {.base.} =
  ## Adds new child in current node.
  ##
  ## Arguments:
  ## - `child`: child node to add.
  if not child.parent.isNil:
    child.pos -= self.absolutePosition()
    child.parent.children.del child.parent.children.find(child)
  self.children.add(child)
  child.parent = self

method drawCore(self: Node, transf: Mat4f) {.base.} =
  discard

proc draw*(self: Node; parent = mat4(1.0f)) =
  ## Draws `self` node.
  var transf = self.transform(parent)
  var myTransf = translate(transf, vec3f(-self.anchor.x, self.anchor.y, 0.0f))
  self.children.sort(proc(x, y: Node):int = cmp(y.zOrder, x.zOrder))
  for node in self.children:
    if node.zOrder < 0:
      node.draw(transf)
  self.drawCore(myTransf)
  for node in self.children:
    if node.zOrder >= 0:
      node.draw(transf)

method getParent*(self: Node): Node {.base.} =
  ## Returns node parent.
  self.parent

method getRootNode*(self: Node): Node {.base.} =
  ## Gets root node.
  result = self
  while result.parent != nil:
    result = result.parent

method find*(self: Node, other: Node): int {.base.} =
  ## Finds a node in `self` and returns its position.
  self.children.find(other)

method removeChild*(self: Node, index: int) {.base.} =
  ## Removes a node at the specified index from `self`.
  ##
  ## Arguments:
  ## - `index`: index of the node to remove.
  self.children.del index

method removeChild*(self: Node, node: Node) {.base.} =
  ## Removes a `node` from `self`.
  ##
  ## Arguments:
  ## - `node`: node to remove.
  let index = self.find(node)
  if index != -1:
    self.removeChild(index)

method removeAll*(self: Node) {.base.} =
  ## Removes all nodes from `self`.
  self.children.setLen 0

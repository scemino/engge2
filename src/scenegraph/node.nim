import glm
import std/algorithm
import ../gfx/color
import ../gfx/recti
import ../game/motors/motor

type
  Node* = ref object of RootObj
    ## Represents a node in a scene graph.
    name*: string                
    parent*: Node                
    children*: seq[Node]         
    pos*: Vec2f
    offset*: Vec2f                  
    renderOffset*: Vec2f                  
    scale*: Vec2f                
    rotation*: float32             
    zOrder*: int32
    anchorNorm: Vec2f
    anchor: Vec2f
    size*: Vec2f
    visible*: bool
    nodeColor*: Color
    zOrderFunc*: proc (): int32
    scaleFunc*: proc (): float32
    buttons*: seq[Button]
    shakeMotor*: Motor
  EventCallback* = proc(node: Node, event: EventKind, pos: Vec2f, tag: pointer)
  Button = ref object of RootObj
    callback*: EventCallback
    inside*: bool
    down*: bool
    tag*: pointer
  EventKind* = enum
    Enter,
    Leave,
    Up,
    Down

proc addButton*(self: Node, callback: EventCallback, tag: pointer = nil) =
  let button = Button(callback: callback, tag: tag)
  self.buttons.add button

proc getRect*(self: Node): Rectf =
  rectFromPositionSize(self.pos, self.size)

method init*(self: Node; visible = true; scale = vec2(1.0f, 1.0f); color = White) {.base.} =
  self.visible = visible
  self.scale = scale
  self.nodeColor = color

proc getZSort*(self: Node): int32 =
  if self.zOrderFunc.isNil: self.zOrder else: self.zOrderFunc()

proc getScale*(self: Node): Vec2f =
  if self.scaleFunc.isNil:
    self.scale
  else: 
    let scale = self.scaleFunc() 
    vec2(scale, scale)

method updateColor(self: Node, color: Color) {.base.} =
  self.nodeColor = rgbaf(color, self.nodeColor.a)

proc newNode*(name: string): Node =
  result.new()
  result.name = name
  result.init()

proc updateChildrenColor(self: Node) =
  for child in self.children:
    child.nodeColor = self.nodeColor

proc `color=`*(self: Node, color: Color) =
  self.updateColor(color)
  self.updateChildrenColor()

proc `color`*(self: Node): Color =
  self.nodeColor

proc `alpha=`*(self: Node, alpha: float) =
  self.nodeColor[3] = clamp(alpha, 0.0f, 1.0f)
  self.updateChildrenColor()

proc `alpha`*(self: Node): float =
  self.nodeColor[3]

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
  var scale = self.getScale()
  scale(rotate(translate(mat4(1.0f), vec3(self.pos + self.offset + self.renderOffset, 0.0f)), glm.radians(self.rotation), 0.0f, 0.0f, 1.0f), scale.x, scale.y, 1.0f)

method transform*(self: Node, parentTrans: Mat4f): Mat4f {.base.} =
  # Gets the full transformation for this node.
  parentTrans * self.localTransform()

proc absolutePosition*(self: Node): Vec2f =
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
    let i = child.parent.children.find(child)
    if i >= 0:
      child.parent.children.del i
  self.children.add(child)
  child.parent = self

method drawCore(self: Node, transf: Mat4f) {.base, locks: "unknown".} =
  discard

proc draw*(self: Node; parent = mat4(1.0f)) =
  ## Draws `self` node.
  if self.visible:
    var transf = self.transform(parent)
    var myTransf = translate(transf, vec3f(-self.anchor.x, self.anchor.y, 0.0f))
    self.children.sort(proc(x, y: Node):int = cmp(y.getZSort, x.getZSort))
    self.drawCore(myTransf)
    for node in self.children:
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

method remove*(self: Node) {.base.} =
  ## Removes this node from its parent.
  if not self.isNil and not self.parent.isNil:
    self.parent.removeChild self

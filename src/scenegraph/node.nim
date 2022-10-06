import std/algorithm
import std/sequtils
import glm
import ../gfx/color
import ../gfx/recti
import ../game/motors/motor
import ../game/screen
import ../game/states/state
import ../sys/app

type
  EventKind* = enum
    Enter,
    Leave,
    Up,
    Down,
    Drag
  EventCallback* = proc(node: Node, event: EventKind, pos: Vec2f, tag: pointer)
  Button = ref object of RootObj
    callback*: EventCallback
    inside*: bool
    down*: bool
    tag*: pointer
  Node* = ref object of RootObj
    ## Represents a node in a scene graph.
    name*: string
    parent*: Node
    children*: seq[Node]
    pos*: Vec2f
    offset*: Vec2f
    renderOffset*: Vec2f
    scale*: Vec2f
    rotation*, rotationOffset*: float32
    zOrder*: int32
    anchorNorm: Vec2f
    anchor: Vec2f
    size*: Vec2f
    visible*: bool
    clr: Color                    # color of the node
    nodeColor: Color              # color to display (depends on parent node's color)
    zOrderFunc*: proc (): int32
    scaleFunc*: proc (): float32
    buttons*: seq[Button]
    shakeMotor*: Motor


proc addButton*(self: Node, callback: EventCallback, tag: pointer = nil) =
  let button = Button(callback: callback, tag: tag)
  self.buttons.add button

method init*(self: Node, visible = true, scale = vec2(1.0f, 1.0f), color = White) {.base.} =
  self.visible = visible
  self.scale = scale
  self.nodeColor = color
  self.clr = color

proc getZSort*(self: Node): int32 =
  if self.zOrderFunc.isNil: self.zOrder else: self.zOrderFunc()

proc getScale*(self: Node): Vec2f =
  if self.scaleFunc.isNil:
    self.scale
  else:
    let scale = self.scaleFunc()
    vec2(scale, scale)

proc newNode*(name: string): Node =
  result.new()
  result.name = name
  result.init()

method colorUpdated(self: Node, color: Color) {.base.} =
  discard

proc updateColor(self: Node, parentColor: Color) =
  self.nodeColor[0] = self.clr[0] * parentColor[0]
  self.nodeColor[1] = self.clr[1] * parentColor[1]
  self.nodeColor[2] = self.clr[2] * parentColor[2]
  self.colorUpdated(self.nodeColor)
  for child in self.children:
    child.updateColor(self.nodeColor)

proc updateColor(self: Node) =
  let parentColor = if self.parent.isNil: White else: self.parent.nodeColor
  self.updateColor(parentColor)

proc `color=`*(self: Node, color: Color) =
  self.clr[0] = color[0]
  self.clr[1] = color[1]
  self.clr[2] = color[2]
  self.nodeColor[0] = color[0]
  self.nodeColor[1] = color[1]
  self.nodeColor[2] = color[2]
  self.updateColor()

proc `color`*(self: Node): Color =
  self.nodeColor

proc `realColor`*(self: Node): Color =
  self.clr

proc updateAlpha(self: Node, parentAlpha: float32) =
  self.nodeColor[3] = self.clr[3] * parentAlpha
  self.colorUpdated(self.nodeColor)
  for child in self.children:
    child.updateAlpha(self.nodeColor[3])

proc updateAlpha(self: Node) =
  let parentOpacity = if self.parent.isNil: 1'f32 else: self.parent.nodeColor[3]
  self.updateAlpha(parentOpacity)

proc `alpha=`*(self: Node, alpha: float) =
  self.clr[3] = alpha
  self.nodeColor[3] = alpha
  self.updateAlpha()

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
  translate(scale(rotate(translate(mat4(1f), vec3(self.pos + self.offset, 0f)), glm.radians(-self.rotation + self.rotationOffset), 0f, 0f, 1f), scale.x, scale.y, 1f), vec3(self.renderOffset, 0f))

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
  child.updateColor()
  child.updateAlpha()

method drawCore(self: Node, transf: Mat4f) {.base, locks: "unknown".} =
  discard

method getRect*(self: Node): Rectf {.base.} =
  let size = self.size * self.scale
  rectFromPositionSize(self.absolutePosition() + vec2(-size.x, size.y) * self.anchorNorm, size)

proc draw*(self: Node; parent = mat4(1f)) =
  ## Draws `self` node.
  if self.visible:
    let transf = self.transform(parent)
    let myTransf = translate(transf, vec3f(-self.anchor.x, self.anchor.y, 0f))
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

proc winToScreen(pos: Vec2f): Vec2f =
  result = (pos / vec2f(appGetWindowSize())) * vec2(ScreenWidth, ScreenHeight)
  result = vec2(result.x, ScreenHeight - result.y)

proc update*(self: Node, elapsed: float, mouseState: MouseState) =
  if self.buttons.len > 0:
    let scrPos = winToScreen(mousePos())
    for btn in self.buttons.toSeq:
      # mouse inside button ?
      if self.getRect().contains(scrPos):
        # enter button ?
        if not btn.inside:
          btn.inside = true
          btn.callback(self, Enter, scrPos, btn.tag)
        # mouse down on button ?
        elif not btn.down and mouseState.click():
          btn.down = true
          btn.callback(self, Down, scrPos, btn.tag)
        # mouse up on button ?
        elif btn.down and mouseState.released():
          btn.down = false
          btn.callback(self, Up, scrPos, btn.tag)
        elif btn.down and mouseState.pressed():
          btn.callback(self, Drag, scrPos, btn.tag)
      # mouse leave button ?
      elif btn.inside:
        btn.inside = false
        btn.callback(self, Leave, scrPos, btn.tag)
      elif btn.down and mouseState.released():
        btn.down = false
        btn.callback(self, Up, scrPos, btn.tag)
      elif btn.down and mouseState.pressed():
        btn.callback(self, Drag, scrPos, btn.tag)

  if not self.shakeMotor.isNil and self.shakeMotor.enabled():
    self.shakeMotor.update(elapsed)

  for node in self.children.toSeq:
    node.update(elapsed, mouseState)
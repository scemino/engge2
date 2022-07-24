import std/logging
import std/strformat
import glm
import node
import ../scenegraph/textnode
import ../game/resmanager
import ../gfx/text
import ../io/yack
import ../io/textdb
import ../io/ggpackmanager
import ../script/vm

const 
  MaxDialogSlots = 9
  MaxChoices = 5
type
  DialogSlot = ref object of Node
    textNode: TextNode
    choice: YChoice
  DialogContext = object
    actor: string
    dialogName: string
  DialogState = enum
    None,
    Active,
    WaitingForChoice
  Dialog* = ref object of Node
    state: DialogState
    context: DialogContext
    currentStatement: int
    cu: YCu
    lbl: YLabel
    parrot: bool
    slots: array[MaxDialogSlots, DialogSlot]
    numSlots: int
  ExpVisitor = ref object of YackVisitor
    dialog: Dialog

proc label(self: Dialog, name: string): YLabel =
  for label in self.cu.labels:
    if label.name == name:
      return label

proc selectLabel(self: Dialog, name: string) =
  info fmt"select label {name}"
  self.lbl = self.label(name)
  self.currentStatement = 0
  self.numSlots = 0
  self.state = if label.isNil: None else: Active

method visit(self: ExpVisitor, node: YCodeExp) =
  info fmt"execute code {node.code}"
  gVm.v.execNut("dialog", node.code)

method visit(self: ExpVisitor, node: YGoto) =
  info fmt"execute goto {node.name}"
  self.dialog.selectLabel(node.name)

method visit(self: ExpVisitor, node: YShutup) =
  warn fmt"TODO: shutup"
  #stopTalking()

method visit(self: ExpVisitor, node: YPause) =
  warn fmt"TODO: pause {node.time}"

method visit(self: ExpVisitor, node: YWaitFor) =
  warn fmt"TODO: waitFor {node.actor}"

method visit(self: ExpVisitor, node: YParrot) =
  self.dialog.parrot = node.active

method visit(self: ExpVisitor, node: YDialog) =
  self.dialog.context.actor = node.actor

method visit(self: ExpVisitor, node: YOverride) =
  warn fmt"TODO: override {node.node}"

method visit(self: ExpVisitor, node: YAllowObjects) =
  warn fmt"TODO: allowObjects"

method visit(self: ExpVisitor, node: YWaitWhile) =
  warn fmt"TODO: wait while"

method visit(self: ExpVisitor, node: YLimit) =
  warn fmt"TODO: limit"

method visit(self: ExpVisitor, node: YSay) =
  discard
  #let actor = actor(node.actor)
  #actor.say(@[node.text], actor.talkColor)

proc addSlot(self: Dialog, choice: YChoice) =
  if self.numSlots < self.slots.len:
    let textNode = newTextNode(newText(gResMgr.font("sayline"), "● " & getText(choice.text), thLeft))
    let y = 8'f32 + textNode.size.y.float32 * (MaxChoices - self.numSlots).float32
    textNode.pos = vec2(8'f32, y)
    self.slots[self.numSlots] = DialogSlot(textNode: textNode, choice: choice)
    self.numSlots += 1
    self.addChild textNode

proc gotoNextLabel(self: Dialog) =
  if not self.lbl.isNil:
    let i = self.cu.labels.find(self.lbl)
    if i != -1 and i != self.cu.labels.len - 1:
      self.selectLabel(self.cu.labels[i+1].name)

proc choicesReady(self: Dialog): bool =
  self.numSlots > 0

proc acceptConditions(self: Dialog, statmt: YStatement): bool =
  # TODO
  true

proc run(self: Dialog, statmt: YStatement) =
  # TODO
  if self.acceptConditions(statmt):
    let visitor = ExpVisitor(dialog: self)
    statmt.exp.accept(visitor)

proc addChoice(self: Dialog, statmt: YStatement) =
  self.addSlot(cast[YChoice](statmt.exp))

proc running(self: Dialog) =
  if self.lbl.isNil:
    self.state = None
  elif self.currentStatement == self.lbl.stmts.len:
    self.gotoNextLabel()
  else:
    self.state = Active
    while self.currentStatement < self.lbl.stmts.len and self.state == Active:
      let statmt = self.lbl.stmts[self.currentStatement]
      if not self.acceptConditions(statmt):
        self.currentStatement += 1
      elif statmt.exp of YChoice:
        self.addChoice(statmt)
        self.currentStatement += 1
      elif self.choicesReady():
        self.state = WaitingForChoice
      else:
        self.run(statmt)

proc newDialog*(): Dialog =
  result = Dialog()
  result.init()

proc update*(self: Dialog, dt: float) =
  case self.state:
  of None:
    discard
  of Active:
    self.running()
  of WaitingForChoice:
    discard

proc start*(self: Dialog, actor, name, node: string) =
  self.context = DialogContext(actor: actor, dialogName: name)
  let path = name & ".byack"
  info fmt"start dialog {path}"
  let code = gGGPackMgr.loadString(path)
  self.cu = parseYack(code, path)
  self.selectLabel(node)

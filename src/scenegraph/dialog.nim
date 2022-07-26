import std/logging
import std/strformat
import glm
import node
import dlgtgt
import ../scenegraph/textnode
import ../game/resmanager
import ../game/motors/motor
import ../gfx/color
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
    dlg: Dialog
  DialogContext = object
    actor: string
    dialogName: string
  DialogState* = enum
    None,
    Active,
    WaitingForChoice
  DialogConditionMode = enum
    Once,
    ShowOnce,
    OnceEver,
    ShowOnceEver,
    TempOnce
  DialogConditionState = object
    mode: DialogConditionMode
    actorKey, dialog: string
    line: int
  Dialog* = ref object of Node
    tgt*: DialogTarget
    action: Motor
    state*: DialogState
    states: seq[DialogConditionState]
    context: DialogContext
    currentStatement: int
    cu: YCu
    lbl: YLabel
    parrot: bool
    slots: array[MaxDialogSlots, DialogSlot]
  ExpVisitor = ref object of YackVisitor
    dialog: Dialog
  CondVisitor = ref object of YackVisitor
    dialog: Dialog
    accepted: bool

proc isOnce(self: Dialog, line: int): bool =
  for state in self.states:
    if state.mode == Once and state.actorKey == self.context.actor and state.dialog == self.context.dialogName and state.line == line:
      info fmt"isOnce {line}: false"
      return false
  info fmt"isOnce {line}: true"
  true

proc isShowOnce(self: Dialog, line: int): bool =
  for state in self.states:
    if state.mode == ShowOnce and state.actorKey == self.context.actor and state.dialog == self.context.dialogName and state.line == line:
      info fmt"isShowOnce {line}: false"
      return false
  info fmt"isShowOnce {line}: true"
  true

proc isOnceEver(self: Dialog, line: int): bool =
  for state in self.states:
    if state.mode == OnceEver and state.dialog == self.context.dialogName and state.line == line:
      info fmt"isOnceEver {line}: false"
      return false
  info fmt"isOnceEver {line}: true"
  true

proc isTempOnce(self: Dialog, line: int): bool =
  for state in self.states:
    if state.mode == TempOnce and state.actorKey == self.context.actor and state.dialog == self.context.dialogName and state.line == line:
      info fmt"isTempOnce {line}: false"
      return false
  info fmt"isTempOnce {line}: true"
  true

proc isCond*(self: Dialog, cond: string): bool =
  result = self.tgt.execCond(cond)
  info fmt"isCond '{cond}': {result}"

proc label(self: Dialog, name: string): YLabel =
  for label in self.cu.labels:
    if label.name == name:
      return label
    
proc numSlots(self: Dialog): int =
  for slot in self.slots:
    if not slot.isNil:
      result += 1

proc clearSlots(self: Dialog) =
  for i in 0..<self.slots.len:
    if not self.slots[i].isNil:
      self.slots[i].textNode.remove()
      self.slots[i] = nil

proc selectLabel(self: Dialog, name: string) =
  info fmt"select label {name}"
  self.lbl = self.label(name)
  self.currentStatement = 0
  self.clearSlots()
  self.state = if self.lbl.isNil: None else: Active

method visit(self: CondVisitor, node: YCodeCond) =
  self.accepted = self.dialog.isCond(node.code)

method visit(self: CondVisitor, node: YOnce) =
  self.accepted = self.dialog.isOnce(node.line)

method visit(self: CondVisitor, node: YShowOnce) =
  self.accepted = self.dialog.isShowOnce(node.line)

method visit(self: CondVisitor, node: YOnceEver) =
  self.accepted = self.dialog.isOnceEver(node.line)

method visit(self: CondVisitor, node: YTempOnce) =
  self.accepted = self.dialog.isTempOnce(node.line)

method visit(self: ExpVisitor, node: YCodeExp) =
  info fmt"execute code {node.code}"
  gVm.v.execNut("dialog", node.code)

method visit(self: ExpVisitor, node: YGoto) =
  info fmt"execute goto {node.name}"
  self.dialog.selectLabel(node.name)

method visit(self: ExpVisitor, node: YShutup) =
  info "shutup"
  self.dialog.tgt.shutup()

method visit(self: ExpVisitor, node: YPause) =
  info fmt"pause {node.time}"
  self.dialog.action = self.dialog.tgt.pause(node.time)

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
  info fmt"wait while"
  self.dialog.action = self.dialog.tgt.waitWhile(node.cond)

method visit(self: ExpVisitor, node: YLimit) =
  warn fmt"TODO: limit"

method visit(self: ExpVisitor, node: YSay) =
  self.dialog.action = self.dialog.tgt.say(node.actor, node.text)

proc onSlot(src: Node, event: EventKind, pos: Vec2f, tag: pointer) =
  let slot = cast[ptr DialogSlot](tag)
  case event:
  of Enter:
    src.color = Red
  of Leave:
    src.color = White
  of Down:
    info fmt"slot selected"
    slot.dlg.selectLabel(slot.choice.goto.name)
  else:
    discard

proc addSlot(self: Dialog, choice: YChoice) =
  if self.slots[choice.number - 1].isNil:
    let textNode = newTextNode(newText(gResMgr.font("sayline"), "● " & getText(choice.text), thLeft))
    let y = 8'f32 + textNode.size.y.float32 * (MaxChoices - self.numSlots).float32
    textNode.pos = vec2(8'f32, y)
    self.slots[choice.number - 1] = DialogSlot(textNode: textNode, choice: choice, dlg: self)
    self.addChild textNode
    self.slots[choice.number - 1].textNode.addButton(onSlot, self.slots[choice.number - 1].addr)

proc gotoNextLabel(self: Dialog) =
  if not self.lbl.isNil:
    let i = self.cu.labels.find(self.lbl)
    if i != -1 and i != self.cu.labels.len - 1:
      self.selectLabel(self.cu.labels[i+1].name)

proc choicesReady(self: Dialog): bool =
  self.numSlots > 0

proc acceptConditions(self: Dialog, statmt: YStatement): bool =
  info fmt"accept {statmt.conds.len} conditions ?"
  let vis = CondVisitor(dialog: self)
  for cond in statmt.conds:
    cond.accept(vis)
    if not vis.accepted:
      info fmt"accept {statmt.conds.len} conditions => no"
      return false
  info fmt"accept {statmt.conds.len} conditions => yes"
  true

proc run(self: Dialog, statmt: YStatement) =
  if self.acceptConditions(statmt):
    let visitor = ExpVisitor(dialog: self)
    statmt.exp.accept(visitor)
  self.currentStatement += 1

proc addChoice(self: Dialog, statmt: YStatement) =
  self.addSlot(cast[YChoice](statmt.exp))

proc running(self: Dialog, dt: float) =
  if not self.action.isNil and self.action.enabled:
    self.action.update(dt)
  elif self.lbl.isNil:
    self.state = None
  elif self.currentStatement == self.lbl.stmts.len:
    self.gotoNextLabel()
  else:
    self.state = Active
    while not self.lbl.isNil and self.currentStatement < self.lbl.stmts.len and self.state == Active:
      let statmt = self.lbl.stmts[self.currentStatement]
      if not self.acceptConditions(statmt):
        self.currentStatement += 1
      elif statmt.exp of YChoice:
        self.addChoice(statmt)
        self.currentStatement += 1
      elif self.choicesReady():
        self.state = WaitingForChoice
      elif not self.action.isNil and self.action.enabled:
        self.action.update(dt)
        return
      else:
        self.run(statmt)
    if self.choicesReady():
        self.state = WaitingForChoice

proc newDialog*(): Dialog =
  result = Dialog()
  result.init()

proc update*(self: Dialog, dt: float) =
  case self.state:
  of None:
    discard
  of Active:
    self.running(dt)
  of WaitingForChoice:
    discard

proc start*(self: Dialog, actor, name, node: string) =
  self.context = DialogContext(actor: actor, dialogName: name)
  let path = name & ".byack"
  info fmt"start dialog {path}"
  let code = gGGPackMgr.loadString(path)
  self.cu = parseYack(code, path)
  self.selectLabel(node)

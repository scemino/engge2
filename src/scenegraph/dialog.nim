import std/logging
import std/strformat
import std/sequtils
import std/algorithm
import glm
import node
import dlgtgt
import sqnim
import ../game/resmanager
import ../game/screen
import ../game/motors/motor
import ../game/motors/action
import ../game/motors/serialmotors
import ../gfx/text
import ../gfx/recti
import ../io/yack
import ../io/textdb
import ../io/ggpackmanager
import ../script/vm
import ../script/squtils
import ../sys/app

const
  MaxDialogSlots = 9
  MaxChoices = 6
  SlidingSpeed = 25f
  SlotMargin = 8f

type
  DialogSlot = ref object of Node
    stamt: YStatement
    dlg: Dialog
    text: Text
  DialogContext = object
    actor: string
    dialogName: string
    parrot: bool
    limit: int
  DialogState* = enum
    None,
    Active,
    WaitingForChoice
  DialogConditionMode* = enum
    Once,
    ShowOnce,
    OnceEver,
    ShowOnceEver,
    TempOnce
  DialogSelMode = enum
    Choose
    Show
  DialogConditionState* = object
    mode*: DialogConditionMode
    actorKey*, dialog*: string
    line*: int
  Dialog* = ref object of Node
    tgt*: DialogTarget
    action: Motor
    state*: DialogState
    states*: seq[DialogConditionState]
    context: DialogContext
    currentStatement: int
    cu: YCu
    lbl: YLabel
    slots: array[MaxDialogSlots, DialogSlot]
    mousePos*: Vec2f
  ExpVisitor = ref object of YackVisitor
    dialog: Dialog
  CondVisitor = ref object of YackVisitor
    dialog: Dialog
    accepted: bool
  CondStateVisitor = ref object of YackVisitor
    mode: DialogSelMode
    dlg: Dialog

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

proc label(self: Dialog, line: int, name: string): YLabel =
  for label in self.cu.labels:
    if label.name == name and label.line >= line:
      return label
  var line = 0
  for label in self.cu.labels:
    if label.name == name and label.line >= line:
      return label

proc numSlots(self: Dialog): int =
  for slot in self.slots:
    if not slot.isNil:
      result += 1

proc clearSlots(self: Dialog) =
  for i in 0..<self.slots.len:
    if not self.slots[i].isNil:
      self.slots[i] = nil

proc selectLabel(self: Dialog, line: int, name: string) =
  info fmt"select label {name}"
  self.lbl = self.label(line, name)
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


proc createState(self: CondStateVisitor, line: int, mode: DialogConditionMode): DialogConditionState =
  DialogConditionState(mode: mode, line: line, dialog: self.dlg.context.dialogName, actorKey: self.dlg.context.actor)

method visit(self: CondStateVisitor, node: YOnce) =
  if self.mode == DialogSelMode.Choose:
    self.dlg.states.add self.createState(node.line, DialogConditionMode.Once)

method visit(self: CondStateVisitor, node: YShowOnce) =
  if self.mode == DialogSelMode.Show:
    self.dlg.states.add self.createState(node.line, DialogConditionMode.ShowOnce)

method visit(self: CondStateVisitor, node: YOnceEver) =
  if self.mode == DialogSelMode.Choose:
    self.dlg.states.add self.createState(node.line, DialogConditionMode.OnceEver)

method visit(self: CondStateVisitor, node: YTempOnce) =
  if self.mode == DialogSelMode.Show:
    self.dlg.states.add self.createState(node.line, DialogConditionMode.TempOnce)


method visit(self: ExpVisitor, node: YCodeExp) =
  info fmt"execute code {node.code}"
  gVm.v.execNut("dialog", node.code)

method visit(self: ExpVisitor, node: YGoto) =
  info fmt"execute goto {node.name}"
  self.dialog.selectLabel(node.line, node.name)

method visit(self: ExpVisitor, node: YShutup) =
  info "shutup"
  self.dialog.tgt.shutup()

method visit(self: ExpVisitor, node: YPause) =
  info fmt"pause {node.time}"
  self.dialog.action = self.dialog.tgt.pause(node.time)

method visit(self: ExpVisitor, node: YWaitFor) =
  warn fmt"TODO: waitFor {node.actor}"

method visit(self: ExpVisitor, node: YParrot) =
  self.dialog.context.parrot = node.active

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
  info fmt"limit"
  self.dialog.context.limit = node.max

method visit(self: ExpVisitor, node: YSay) =
  self.dialog.action = self.dialog.tgt.say(node.actor, node.text)

proc choice(self: YStatement): YChoice {.inline.} =
  cast[YChoice](self.exp)

proc choice(self: DialogSlot): YChoice {.inline.} =
  choice(self.stamt)

proc choose(slot: DialogSlot) =
  if not slot.isNil:
    sqCall("onChoiceClick")
    for cond in slot.stamt.conds:
      let v = CondStateVisitor(dlg: slot.dlg, mode: DialogSelMode.Choose)
      cond.accept(v)
    if slot.dlg.context.parrot:
      slot.dlg.state = DialogState.Active
      slot.dlg.action = newSerialMotors(
        [slot.dlg.tgt.say(slot.dlg.context.actor, slot.choice.text), newActionMotor(proc () = slot.dlg.selectLabel(slot.choice.goto.line, slot.choice.goto.name))])
      slot.dlg.clearSlots()
    else:
      slot.dlg.selectLabel(slot.choice.goto.line, slot.choice.goto.name)

proc choose*(self: Dialog, choice: int) =
  if self.state == WaitingForChoice:
    choose(self.slots[choice])

proc remove(txt: string, startC, endC: char): string =
  result = txt
  if result[0] == startC:
    let i = result.find(endC)
    if i != -1:
      result = result[i+1..^1]

proc text(txt: string): string =
  result = getText(txt)
  result = remove(result, '(', ')')
  result = remove(result, '{', '}')

proc addSlot(self: Dialog, stamt: YStatement) =
  let choice = stamt.choice
  if self.slots[choice.number - 1].isNil and self.numSlots() < self.context.limit:
    let text = newText(gResMgr.font("sayline"), "● " & text(choice.text), thLeft, tvTop)
    let slot = DialogSlot(text: text, stamt: stamt, dlg: self)
    let y = SlotMargin + text.bounds.y.float32 * (MaxChoices - self.numSlots).float32
    slot.pos = vec2(SlotMargin, y)
    self.slots[choice.number - 1] = slot

method drawCore(self: Dialog, transf: Mat4f) =
  for slot in self.slots:
    if not slot.isNil:
      let t = translate(transf, vec3(slot.pos, 0f))
      slot.text.draw(t)

proc gotoNextLabel(self: Dialog) =
  if not self.lbl.isNil:
    let i = self.cu.labels.find(self.lbl)
    if i != -1 and i != self.cu.labels.len - 1:
      let label = self.cu.labels[i+1]
      self.selectLabel(label.line, label.name)
    else:
      self.state = None

proc choicesReady(self: Dialog): bool =
  self.numSlots > 0

proc acceptConditions(self: Dialog, statmt: YStatement): bool =
  let vis = CondVisitor(dialog: self)
  for cond in statmt.conds:
    cond.accept(vis)
    if not vis.accepted:
      return false
  true

proc updateChoiceStates(self: Dialog) =
  self.state = WaitingForChoice
  for slot in self.slots:
    if not slot.isNil:
      for cond in slot.stamt.conds:
        let v = CondStateVisitor(dlg: self, mode: DialogSelMode.Show)
        cond.accept(v)

proc run(self: Dialog, statmt: YStatement) =
  if self.acceptConditions(statmt):
    let visitor = ExpVisitor(dialog: self)
    statmt.exp.accept(visitor)
    if statmt.exp of YGoto:
      return
  self.currentStatement += 1

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
        self.addSlot(statmt)
        self.currentStatement += 1
      elif self.choicesReady():
        self.updateChoiceStates()
      elif not self.action.isNil and self.action.enabled:
        self.action.update(dt)
        return
      else:
        self.run(statmt)
        if not self.lbl.isNil and self.currentStatement == self.lbl.stmts.len:
          self.gotoNextLabel()
    if self.choicesReady():
        self.updateChoiceStates()
    elif self.action.isNil or not self.action.enabled:
      self.state = None

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
    let color = self.tgt.actorColor(self.context.actor)
    let colorHover = self.tgt.actorColorHover(self.context.actor)
    var i = 0
    for slot in self.slots.mitems:
      if not slot.isNil:
        let rect = rectFromPositionSize(slot.pos - vec2(0f, slot.text.bounds.y), slot.text.bounds)
        let over = not slot.isNil and rect.contains(self.mousePos)
        if rect.w > (ScreenWidth - SlotMargin):
          if over:
            if (rect.w + slot.pos.x) > (ScreenWidth - SlotMargin):
              slot.pos.x -= SlidingSpeed * dt
              if (rect.w + slot.pos.x) < (ScreenWidth - SlotMargin):
                slot.pos.x = (ScreenWidth - SlotMargin) - rect.w
          elif slot.pos.x < SlotMargin:
            slot.pos.x += SlidingSpeed * dt
            if slot.pos.x > SlotMargin:
              slot.pos.x = SlotMargin

        slot.text.color = if over: colorHover else: color
        if over and mbLeft in mouseBtns():
          self.choose(i)
      inc i

proc start*(self: Dialog, actor, name, node: string) =
  self.context = DialogContext(actor: actor, dialogName: name, parrot: true, limit: MaxChoices)
  keepIf(self.states, proc(x: DialogConditionState): bool = x.mode != TempOnce)
  let path = name & ".byack"
  info fmt"start dialog {path}"
  let code = gGGPackMgr.loadString(path)
  self.cu = parseYack(code, path)
  self.selectLabel(0, node)
  self.update(0)

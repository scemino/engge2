import std/[lexbase, streams, strutils, strformat]

type
  TokenId = enum
    Error,
    NewLine
    Identifier,
    WaitWhile,
    WaitFor,
    Int,
    Float,
    Colon,
    Condition,
    String,
    Assign,
    Goto,
    Code,
    Dollar,
    End

  YackError* = enum       ## enumeration that lists all errors that can occur
    errNone,              ## no error
    errInvalidToken,      ## invalid token
    errStringExpected,    ## string expected
    errColonExpected,     ## `:` expected
    errCommaExpected,     ## `,` expected
    errBracketRiExpected, ## `]` expected
    errCurlyRiExpected,   ## `}` expected
    errQuoteExpected,     ## `"` or `'` expected
    errEOC_Expected,      ## `*/` expected
    errEofExpected,       ## EOF expected
    errExprExpected       ## expr expected
  YackParsingError* = object of ValueError ## is raised for a Yack error
  YackParser = object of BaseLexer
    a*: string
    filename*: string
    tok*: TokenId
    err: YackError
  YackVisitor* = ref object of RootObj
  DumpYack = ref object of YackVisitor
    indt: int
  
  YackNode* = ref object of RootObj ## YackNode node
  YCu* = ref object of YackNode
    labels*: seq[YLabel]
  YLabel* = ref object of YackNode
    name*: string
    stmts*: seq[YStatement]
  YStatement* = ref object of YackNode
    exp*: YExp
    conds*: seq[YCond]

  YCond* = ref object of YackNode ## condition
    line*: int
  YCodeCond* = ref object of YCond ## Code condition
    code*: string
  YOnce* = ref object of YCond
  YShowOnce* = ref object of YCond
  YOnceEver* = ref object of YCond
  YTempOnce* = ref object of YCond
  
  YExp* = ref object of YackNode ## Expression
  YGoto* = ref object of YExp
    name*: string
  YCodeExp* = ref object of YExp
    code*: string
  YChoice* = ref object of YExp
    number*: int
    text*: string
    goto*: YGoto
  YSay* = ref object of YExp
    actor*: string
    text*: string
  YPause* = ref object of YExp
    time*: float
  YParrot* = ref object of YExp
    active*: bool
  YDialog* = ref object of YExp
    actor*: string
  YOverride* = ref object of YExp
    node*: string
  YShutup* = ref object of YExp
  YAllowObjects* = ref object of YExp
    active*: bool
  YLimit* = ref object of YExp
    max*: int
  YWaitWhile* = ref object of YExp
    cond*: string
  YWaitFor* = ref object of YExp
    actor*: string

const
  tokToStr: array[TokenId, string] = [
    "invalid token",
    "newline",
    "identifier",
    "waitwhile",
    "waitfor",
    "int literal",
    "float literal",
    ":",
    "condition",
    "string literal",
    "=",
    "goto",
    "code",
    "$",
    "EOF"
  ]

method accept*(node: YackNode, v: YackVisitor) {.base.} =
  discard

method defaultVisit*(v: YackVisitor, node: YackNode) {.base.} =
  discard

method visit*(v: YackVisitor, node: YCu) {.base.} =
  v.defaultVisit(node)

method visit*(v: YackVisitor, node: YStatement) {.base.} =
  v.defaultVisit(node)

method visit*(v: YackVisitor, node: YLabel) {.base.} =
  v.defaultVisit(node)

method visit*(v: YackVisitor, node: YSay) {.base.} =
  v.defaultVisit(node)

method visit*(v: YackVisitor, node: YChoice) {.base.} =
  v.defaultVisit(node)

method visit*(v: YackVisitor, node: YCodeExp) {.base.} =
  v.defaultVisit(node)

method visit*(v: YackVisitor, node: YGoto) {.base.} =
  v.defaultVisit(node)

method visit*(v: YackVisitor, node: YCodeCond) {.base.} =
  v.defaultVisit(node)

method visit*(v: YackVisitor, node: YOnce) {.base.} =
  v.defaultVisit(node)

method visit*(v: YackVisitor, node: YShowOnce) {.base.} =
  v.defaultVisit(node)

method visit*(v: YackVisitor, node: YOnceEver) {.base.} =
  v.defaultVisit(node)

method visit*(v: YackVisitor, node: YTempOnce) {.base.} =
  v.defaultVisit(node)

method visit*(v: YackVisitor, node: YShutup) {.base.} =
  v.defaultVisit(node)

method visit*(v: YackVisitor, node: YPause) {.base.} =
  v.defaultVisit(node)

method visit*(v: YackVisitor, node: YWaitFor) {.base.} =
  v.defaultVisit(node)
  
method visit*(v: YackVisitor, node: YParrot) {.base.} =
  v.defaultVisit(node)

method visit*(v: YackVisitor, node: YDialog) {.base.} =
  v.defaultVisit(node)

method visit*(v: YackVisitor, node: YOverride) {.base.} =
  v.defaultVisit(node)

method visit*(v: YackVisitor, node: YAllowObjects) {.base.} =
  v.defaultVisit(node)

method visit*(v: YackVisitor, node: YWaitWhile) {.base.} =
  v.defaultVisit(node)

method visit*(v: YackVisitor, node: YLimit) {.base.} =
  v.defaultVisit(node)


method accept*(node: YCu, v: YackVisitor) =
  v.visit(node)

method accept*(node: YStatement, v: YackVisitor) =
  v.visit(node)

method accept*(node: YLabel, v: YackVisitor) =
  v.visit(node)

method accept*(node: YSay, v: YackVisitor) =
  v.visit(node)

method accept*(node: YChoice, v: YackVisitor) =
  v.visit(node)

method accept*(node: YCodeExp, v: YackVisitor) =
  v.visit(node)

method accept*(node: YGoto, v: YackVisitor) =
  v.visit(node)

method accept*(node: YCodeCond, v: YackVisitor) =
  v.visit(node)

method accept*(node: YOnce, v: YackVisitor) =
  v.visit(node)

method accept*(node: YShowOnce, v: YackVisitor) =
  v.visit(node)

method accept*(node: YOnceEver, v: YackVisitor) =
  v.visit(node)

method accept*(node: YTempOnce, v: YackVisitor) =
  v.visit(node)

method accept*(node: YShutup, v: YackVisitor) =
  v.visit(node)

method accept*(node: YPause, v: YackVisitor) =
  v.visit(node)

method accept*(node: YWaitFor, v: YackVisitor) =
  v.visit(node)
  
method accept*(node: YParrot, v: YackVisitor) =
  v.visit(node)

method accept*(node: YDialog, v: YackVisitor) =
  v.visit(node)

method accept*(node: YOverride, v: YackVisitor) =
  v.visit(node)

method accept*(node: YAllowObjects, v: YackVisitor) =
  v.visit(node)

method accept*(node: YWaitWhile, v: YackVisitor) =
  v.visit(node)

method accept*(node: YLimit, v: YackVisitor) =
  v.visit(node)

proc pindent(v: DumpYack, msg: string) =
  echo " ".repeat(v.indt) & msg

proc indent(v: DumpYack) =
  v.indt += 1

proc unindent(v: DumpYack) =
  v.indt -= 1

method visit(v: DumpYack, node: YCodeExp) =
  v.pindent("CodeExp: " & node.code)

method visit(v: DumpYack, node: YGoto) =
  v.pindent("Goto: " & node.name)

method visit(v: DumpYack, node: YShutup) =
  v.pindent("Shutup")

method visit(v: DumpYack, node: YPause) =
  v.pindent("Pause: " & $node.time)

method visit(v: DumpYack, node: YWaitFor) =
  v.pindent("WaitFor " & node.actor)

method visit(v: DumpYack, node: YParrot) =
  v.pindent("Parrot: " & $node.active)

method visit(v: DumpYack, node: YDialog) =
  v.pindent("Dialog: " & node.actor)

method visit(v: DumpYack, node: YOverride) =
  v.pindent("Override")

method visit(v: DumpYack, node: YAllowObjects) =
  v.pindent("AllowObjects")

method visit(v: DumpYack, node: YWaitWhile) =
  v.pindent("WaitWhile " & node.cond)

method visit(v: DumpYack, node: YLimit) =
  v.pindent("Limit")

method visit(v: DumpYack, node: YChoice) =
  v.pindent("Choice " & $node.number & ": " & node.text & " goto " & node.goto.name)

method visit(v: DumpYack, node: YSay) =
  v.pindent(node.actor & " say " & node.text)

method visit(v: DumpYack, node: YStatement) =
  v.pindent("Statement")
  v.indent()
  node.exp.accept(v)
  v.unindent()
  if node.conds.len != 0:
    v.pindent("Conditions")
    v.indent()
    for cond in node.conds:
      cond.accept(v)
    v.unindent()

method visit(v: DumpYack, node: YLabel) =
  v.pindent "Label: " & node.name
  v.indent()
  for st in node.stmts:
    st.accept(v)
  v.unindent()

method visit(v: DumpYack, node: YCu) =
  v.pindent("Compilation Unit:")
  v.indent()
  for label in node.labels:
    label.accept(v)
  v.unindent()

method visit*(v: DumpYack, node: YCodeCond)  =
  v.pindent("Code condition: " & node.code)

method visit*(v: DumpYack, node: YOnce)  =
  v.pindent(fmt"Once condition: [{$node.line}]")

method visit*(v: DumpYack, node: YShowOnce) =
  v.pindent(fmt"Show Once condition: [{$node.line}]")

method visit*(v: DumpYack, node: YOnceEver) =
  v.pindent(fmt"Once ever condition: [{$node.line}]")

method visit*(v: DumpYack, node: YTempOnce) =
  v.defaultVisit(node)

proc open*(self: var YackParser, input: Stream, bufLen: int = 8192) =
  ## initializes the parser with an input stream.
  lexbase.open(self, input, bufLen)

proc close*(self: var YackParser) {.inline.} =
  ## closes the parser `self` and its associated input stream.
  lexbase.close(self)

proc skip(self: var YackParser, skipNewLine = true) =
  var pos = self.bufpos
  while true:
    case self.buf[pos]
    of ';':
      # skip line comment:
      inc(pos)
      while true:
        case self.buf[pos]
        of '\0':
          break
        of '\c':
          pos = lexbase.handleCR(self, pos)
          break
        of '\L':
          pos = lexbase.handleLF(self, pos)
          break
        else:
          inc(pos)
    of ' ', '\t':
      inc(pos)
    of '\c':
      pos = lexbase.handleCR(self, pos)
    of '\L':
      if skipNewLine:
        pos = lexbase.handleLF(self, pos)
      else:
        break
    else:
      break
  self.bufpos = pos

proc parseNumber(self: var YackParser) =
  var pos = self.bufpos
  if self.buf[pos] == '-':
    add(self.a, '-')
    inc(pos)
  if self.buf[pos] == '.':
    add(self.a, "0.")
    inc(pos)
  else:
    while self.buf[pos] in Digits:
      add(self.a, self.buf[pos])
      inc(pos)
    if self.buf[pos] == '.':
      add(self.a, '.')
      inc(pos)
  # digits after the dot:
  while self.buf[pos] in Digits:
    add(self.a, self.buf[pos])
    inc(pos)
  if self.buf[pos] in {'E', 'e'}:
    add(self.a, self.buf[pos])
    inc(pos)
    if self.buf[pos] in {'+', '-'}:
      add(self.a, self.buf[pos])
      inc(pos)
    while self.buf[pos] in Digits:
      add(self.a, self.buf[pos])
      inc(pos)
  self.bufpos = pos

proc parseString(self: var YackParser): TokenId =
  result = String
  var pos = self.bufpos + 1
  while true:
    case self.buf[pos]
    of '\0':
      self.err = errQuoteExpected
      result = Error
      break
    of '"':
      inc(pos)
      break
    of '\\':
      case self.buf[pos+1]
      of '\\', '"', '\'', '/':
        add(self.a, self.buf[pos+1])
        inc(pos, 2)
      of 'b':
        add(self.a, '\b')
        inc(pos, 2)
      of 'f':
        add(self.a, '\f')
        inc(pos, 2)
      of 'n':
        add(self.a, '\L')
        inc(pos, 2)
      of 'r':
        add(self.a, '\C')
        inc(pos, 2)
      of 't':
        add(self.a, '\t')
        inc(pos, 2)
      of 'v':
        add(self.a, '\v')
        inc(pos, 2)
      else:
        # don't bother with the error
        add(self.a, self.buf[pos])
        inc(pos)
    of '\c':
      pos = lexbase.handleCR(self, pos)
      add(self.a, '\c')
    of '\L':
      pos = lexbase.handleLF(self, pos)
      add(self.a, '\L')
    else:
      add(self.a, self.buf[pos])
      inc(pos)
  self.bufpos = pos # store back

proc parseCondition(self: var YackParser): TokenId =
  result = Condition
  var pos = self.bufpos + 1
  while true:
    case self.buf[pos]
    of '\0':
      self.err = errBracketRiExpected
      result = Error
      break
    of ']':
      inc(pos)
      break
    else:
      add(self.a, self.buf[pos])
      inc(pos)
  self.bufpos = pos # store back

proc parseCode(self: var YackParser): TokenId =
  result = Code
  var pos = self.bufpos + 1
  # echo "parse code " & $pos
  while true:
    case self.buf[pos]
    of '\0', '\n':
      inc(pos)
      break
    of '[':
      if self.buf[pos - 1] == ' ' and self.buf[pos + 1] != ' ':
        break
      add(self.a, self.buf[pos])
      inc(pos)
    else:
      add(self.a, self.buf[pos])
      inc(pos)
  self.bufpos = pos # store back

proc parseDollar(self: var YackParser): TokenId =
  result = Dollar
  var pos = self.bufpos + 1
  while true:
    case self.buf[pos]
    of '\0', ' ', '\n':
      inc(pos)
      break
    of '[':
      break
    else:
      add(self.a, self.buf[pos])
      inc(pos)
  self.bufpos = pos # store back

proc parseIdentifier(self: var YackParser): TokenId =
  result = Identifier
  var pos = self.bufpos
  while self.buf[pos] in IdentChars:
    add(self.a, self.buf[pos])
    inc(pos)
  if self.a == "waitwhile":
    self.bufpos = pos
    setLen(self.a, 0)
    discard self.parseCode()
    result = WaitWhile
  elif self.a == "waitfor":
    self.bufpos = pos
    setLen(self.a, 0)
    self.skip(false)
    # echo "parse waitfor1 '" & self.buf[self.bufpos] & "' '" &  $(self.buf[self.bufpos]=='\n') & "'" & $self.bufpos
    discard self.parseIdentifier()
    # echo "parse waitfor2 '" & self.buf[self.bufpos] & "' '" &  $(self.buf[self.bufpos]=='\n') & "'" & $self.bufpos
    result = WaitFor
  else:
    self.bufpos = pos # store back

proc getTokCore(self: var YackParser): TokenId =
  setLen(self.a, 0)
  self.skip(false) # skip whitespace, comments
  case self.buf[self.bufpos]
  of '\L':
    self.bufpos = lexbase.handleLF(self, self.bufpos)
    result = NewLine
  of '!':
    result = parseCode(self)
  of ':':
    inc(self.bufpos)
    result = Colon
  of '$':
    result = parseDollar(self)
  of '[':
    result = parseCondition(self)
  of '=':
    inc(self.bufpos)
    result = Assign
  of '"':
    result = parseString(self)
  of '\0':
    result = End
  else:
    if self.buf[self.bufpos] == '-' and self.buf[self.bufpos + 1] == '>':
      self.bufpos += 2
      result = Goto
    elif self.buf[self.bufpos] == '-' or self.buf[self.bufpos] in Digits:
      parseNumber(self)
      if {'.', 'e', 'E'} in self.a:
        result = Float
      else:
        result = Int
    elif self.buf[self.bufpos] in IdentStartChars:
      result = parseIdentifier(self)
    else:
      inc(self.bufpos)
      result = Error
  self.tok = result

proc getTok(self: var YackParser, ignoreErrors = true): TokenId =
  result = self.getTokCore()
  if result == Error and ignoreErrors:
    result = self.getTok(true)

proc match(p: var YackParser, ids: openArray[TokenId]): bool =
  let pos = p.bufPos
  let tok = p.tok
  var a = p.a
  for id in ids:
    if p.tok != id:
      p.bufPos = pos
      p.tok = tok
      p.a = a
      return false
    discard p.getTok()
  p.bufPos = pos
  p.tok = tok
  p.a = a
  true

proc filename*(self: YackParser): string {.inline.} =
  ## get the current line the parser has arrived at.
  result = self.filename

proc getColumn*(self: YackParser): int {.inline.} =
  ## get the current column the parser has arrived at.
  result = getColNumber(self, self.bufpos)

proc getLine*(self: YackParser): int {.inline.} =
  ## get the current line the parser has arrived at.
  result = self.lineNumber

proc errorMsgExpected*(self: YackParser, e: string, a: string): string =
  ## returns an error message "`e` expected" in the same format as the
  ## other error messages
  result = "$1($2, $3) Error: $4 $5" % [
    self.filename, $getLine(self), $getColumn(self), e & " expected", if a.len>0: "actual is " & a else: a]

proc raiseParseErr*(p: YackParser, msg: string, actual = "") {.noinline, noreturn.} =
  ## raises an `YackParsingError` exception.
  raise newException(YackParsingError, errorMsgExpected(p, msg, actual))

proc eat*(p: var YackParser, tok: TokenId): string =
  if p.tok == tok:
    result = p.a
    discard getTok(p)
  else: 
    raiseParseErr(p, tokToStr[tok], tokToStr[p.tok] & "(" & $p.a & ")")

proc parseSayExp(p: var YackParser): YSay =
  result = YSay()
  result.actor = p.eat(TokenId.Identifier)
  discard p.eat(TokenId.Colon)
  result.text = p.eat(TokenId.String)

proc parseWaitWhileExp(p: var YackParser): YWaitWhile =
  result = YWaitWhile(cond: p.eat(TokenId.WaitWhile))

proc parseWaitForExp(p: var YackParser): YWaitFor =
  result = YWaitFor(actor: p.eat(TokenId.WaitFor))

proc parseGotoExp(p: var YackParser): YGoto =
  discard p.eat(TokenId.Goto)
  result = YGoto(name: p.eat(TokenId.Identifier))

proc parseChoiceExp(p: var YackParser): YChoice =
  var text: string
  let number = parseInt(p.eat(TokenId.Int))
  if p.match([TokenId.Dollar]):
    text = p.eat(TokenId.Dollar)
  elif p.match([TokenId.String]):
    text = p.eat(TokenId.String)
  else:
    raiseParseErr(p, "$ or string")

  YChoice(number: number, text: text, goto: p.parseGotoExp())

proc parseCodeExp(p: var YackParser): YCodeExp =
  YCodeExp(code: p.eat(TokenId.Code))

proc parseInstExp(p: var YackParser): YExp =
  let ident = p.eat(TokenId.Identifier)
  if ident == "shutup":
    result = YShutup()
  elif ident == "pause":
    # pause time
    if p.match([TokenId.Float]):
      result = YPause(time: parseFloat(p.eat(TokenId.Float)))
    elif p.match([TokenId.Int]):
      result = YPause(time: parseInt(p.eat(TokenId.Int)).toFloat)
    else:
      raiseParseErr(p, "time")
  elif ident == "parrot":
    # parrot
    # parrot NO
    # parrot YES
    if p.match([TokenId.Identifier]):
      result = YParrot(active: cmpIgnoreCase(p.eat(TokenId.Identifier), "YES") == 0)
    else:
      result = YParrot(active: true)
  elif ident == "dialog":
    # dialog
    # dialog actor
    if p.match([TokenId.Identifier]):
      result = YDialog(actor: p.eat(TokenId.Identifier))
    else:
      result = YDialog()
  elif ident == "override":
    # override
    # override node
    if p.match([TokenId.Identifier]):
      result = YOverride(node: p.eat(TokenId.Identifier))
    else:
      result = YOverride()
  elif ident == "allowobjects":
    # allowobjects
    # allowobjects YES
    # allowobjects NO
    if p.match([TokenId.Identifier]):
      result = YAllowObjects(active: cmpIgnoreCase(p.eat(TokenId.Identifier), "YES") == 0)
    else:
      result = YAllowObjects(active: true)
  elif ident == "limit":
    # limit
    # limit max
    if p.match([TokenId.Int]):
      result = YLimit(max: parseInt(p.eat(TokenId.Int)))
    else:
      result = YLimit()
  else:
    raiseParseErr(p, "instruction", ident)

proc parseExp(p: var YackParser): YExp =
  if p.match([TokenId.Identifier, TokenId.Colon, TokenId.String]):
    result = p.parseSayExp()
  elif p.match([TokenId.WaitWhile]):
    result = p.parseWaitWhileExp()
  elif p.match([TokenId.WaitFor]):
    result = p.parseWaitForExp()
  elif p.match([TokenId.Identifier]):
    result = p.parseInstExp()
  elif p.match([TokenId.Goto]):
    result = p.parseGotoExp()
  elif p.match([TokenId.Int]):
    result = p.parseChoiceExp()
  elif p.match([TokenId.Code]):
    result = p.parseCodeExp()
  else:
    raiseParseErr(p, "expression", tokToStr[p.tok] & "(" & $p.a & ")")

proc parseCond(p: var YackParser): YCond =
  let conditionText = p.eat(TokenId.Condition)
  let line = p.getLine()
  assert(line > 0);
  if conditionText == "once":
    result = YOnce(line: line)
  elif conditionText == "showonce":
    result = YShowOnce(line: line)
  elif conditionText == "onceever":
    result = YOnceEver(line: line)
  elif conditionText == "temponce":
    result = YTempOnce(line: line)
  else:
    result = YCodeCond(line: line, code: conditionText)

proc parseStat(p: var YackParser): YStatement =
  result = YStatement(exp: p.parseExp())
  while p.match([TokenId.Condition]):
    result.conds.add(p.parseCond())

proc parseLabel(p: var YackParser): YLabel =
  result = YLabel()

  # skip new lines
  while p.match([TokenId.NewLine]):
    discard p.eat(p.tok)

  discard p.eat(TokenId.Colon)
  result.name = p.eat(TokenId.Identifier)

  # skip until new line
  while not p.match([TokenId.NewLine]):
    discard p.eat(p.tok)

  while true:
    while p.match([TokenId.NewLine]):
      discard p.eat(p.tok)
    if p.match([TokenId.Colon]) or p.match([TokenId.End]):
      break
    let stat = p.parseStat()
    result.stmts.add(stat)

proc parseYack(p: var YackParser): YCu =
  ## Parses Yack from a Yack Parser `p`.
  result = Ycu()
  while not p.match([End]):
    result.labels.add(p.parseLabel())

proc parseYack*(s: Stream, bufLen: int = 8192, filename = ""): YCu =
  ## Parses from a stream `s` into a `YackNode`. 
  ## This closes the stream `s` after it's done.
  var p: YackParser
  p.open(s, bufLen)
  p.filename = filename
  try:
    discard getTok(p) # read first token
    result = p.parseYack()
    # eat(p, tiEnd) # check if there is no extra data
  finally:
    p.close()

iterator tokens*(s: Stream): (TokenId,string) =
  ## Parses from a stream `s` into a `YackNode`. 
  ## This closes the stream `s` after it's done.
  var p: YackParser
  p.open(s)
  try:
    while getTok(p, false) != TokenId.End:
      yield (p.tok, p.a)
    # eat(p, tiEnd) # check if there is no extra data
  finally:
    p.close()

iterator tokens*(buffer: string): (TokenId,string) =
  for t in tokens(newStringStream(buffer)):
    yield t

proc parseYack*(buffer, filename: string): YCu =
  result = parseYack(newStringStream(buffer), buffer.len + 1, filename)

when isMainModule:
  import std/os

  let code = """
:init
-> exit

:start
sandy: "Ahoy there, stranger."
sandy: "New in town?"
waitfor
!playObjectState(Pirate1.pirate, 1)

:main
1 "My name's Guybrush Threepwood. I'm new in town." -> laughing
2 "Are you a pirate? Can I be on your crew?" -> crew
3 "Who's in charge here?" -> charge
4 "Nice talking to you." -> nice_talking

:crew
sandy: "Well, I'm a pirate."
sandy: "But, alas, I'm not a captain."
waitfor
!playObjectState(Pirate1.pirate, 1)
-> important_looking

:laughing
sandy: "Guybrush Threepwood?"
waitfor
!!objectHidden(Pirate1.pirate_laughing, NO)
sandy: "Ah ah ah!!!"
sandy: "That's the stupidest name on earth I've ever heard."
-> main2

:charge
sandy: "Well, this island has a governor..."
sandy: "...but we pirates have our own leaders."
waitfor
!playObjectState(Pirate1.pirate, 1)
1 "I want to talk to the leaders of the pirates." -> important_looking
2 "Where can I find the Governor of the island?" -> governor
3 "That's nice. Goodbye." -> done

:main2
1 "I don't know, I kind of like 'Guybrush'" -> not_name
2 "Well, what's YOUR name?" -> name
3 "Yeah, it is pretty dumb, isn't it?" -> dumb
4 "I'm insulted. Goodbye." -> done

:not_name
sandy: "But it's not even a name."
-> main2

:dumb
!!objectHidden(Pirate1.pirate_laughing, YES)
sandy: "That's okay."
sandy: "Mine is Macom Seepgood."
-> melee_island

:name
waitfor
!!objectHidden(Pirate1.pirate_laughing, YES)
sandy: "My name is Macomb Seepgood"

:melee_island
sandy: "So what brings you to Mêlée Island™ anyway?"
!playObjectState(Pirate1.pirate, 1)
-> main3

:main3
1 "I want to be a pirate" -> pirate [once]
2 "I've come seeking my fortune" -> fortune
3 "I really don't know" -> sunshine
4 "None of your business. Goodbye." -> done

:sunshine
sandy: "Well it sure wasn't for the sunshine"

:fortune
sandy: "Oh, you have, have you?"
-> important_looking

:pirate
sandy: "Oh really?"

:important_looking
waitfor
!playObjectState(Pirate1.pirate, 1)
sandy: "You should go talk to the important-looking pirates in the next room."
sandy: "They're pretty much in charge here."
sandy: "They can tell you where to go and what to do."
1 "Where can I find the Governor?" -> governor
2 "Nice talking to you." -> nice_talking

:governor
sandy: "Governor Marley?"
sandy: "Her mansion is on the other side of town."
sandy: "But pirates aren't as welcome around her place as they used to be."
1 "Why not?" -> unwelcome
2 "I'm welcome everywhere I go." -> welcome
3 "I think I'll go there right now. Bye." -> done

:unwelcome
sandy: "Well, the last time she has a pirate over for dinner, he fell in love with her."
sandy: "It's made things rather uncomfortable for everybody."
1 "How that?" -> story
2 "Who is this pirate?" -> done
3 "That's too bad. Well, see you later." -> done

:story
sandy: "Well, there's a whole big story about what happened next..."
sandy: "Estevan over there at the other table might tell you about it."
sandy: "He takes the whole thing seriously."
waitfor
!objectHidden(Pirate1.pirate_laughing, NO)
sandy: "VERY seriously."
waitfor
!objectHidden(Pirate1.pirate_laughing, YES)
-> grog

:welcome
sandy: "Whatever you say."
sandy: "Just watch out those guard dogs!"

:grog
sandy: "Uh-oh, it looks like my grog is gooing flat, so you'll have to excuse me."

:nice_talking
sandy: "Nice talking to you."
sandy: "Have fun on Mêlée Island™."
!playObjectState(Pirate1.pirate, 1)

:done
-> exit


"""
  for t in tokens(code):
    echo t
  let yack = parseYack(code, "")
  DumpYack().visit(yack)

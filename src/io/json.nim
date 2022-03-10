import std/[lexbase, streams, strutils, tables]

type
  JsonEventKind* = enum ## enumeration of all events that may occur when parsing
    jsonError,
    jsonInt,
    jsonFloat,
    jsonColon,
    jsonComma,
    jsonString,
    jsonStartHash,
    jsonEndHash,
    jsonStartArray,
    jsonEndArray,
    jsonEnd
  TokenId* = enum
    tiError,
    tiInt,
    tiFloat,
    tiColon,
    tiComma,
    tiString,
    tiCurlyLe,
    tiCurlyRi,
    tiBracketLe,
    tiBracketRi,
    tiEnd
  JsonError* = enum       ## enumeration that lists all errors that can occur
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
  JsonParser* = object of BaseLexer ## the parser object.
    a*: string
    tok*: TokenId
    kind: JsonEventKind
    err: JsonError
    filename: string
    rawStringLiterals: bool
  JsonParsingError* = object of ValueError ## is raised for a JSON error
  JsonNodeKind* = enum ## possible JSON node types
    JInt,
    JFloat,
    JString,
    JObject,
    JArray

  JsonNode* = ref JsonNodeObj ## JSON node
  JsonNodeObj* {.acyclic.} = object
    isUnquoted: bool # the JString was a number-like token and
                     # so shouldn't be quoted
    case kind*: JsonNodeKind
    of JString:
      str*: string
    of JInt:
      num*: BiggestInt
    of JFloat:
      fnum*: float
    of JObject:
      fields*: OrderedTable[string, JsonNode]
    of JArray:
      elems*: seq[JsonNode]

const
  tokToStr: array[TokenId, string] = [
    "invalid token",
    "int literal",
    "float literal",
    ":",
    ",",
    "string literal",
    "{", "}", "[", "]",
    "EOF"
  ]

proc open*(self: var JsonParser, input: Stream, filename: string;
           rawStringLiterals = false) =
  ## initializes the parser with an input stream. `Filename` is only used
  ## for nice error messages. If `rawStringLiterals` is true, string literals
  ## are kept with their surrounding quotes and escape sequences in them are
  ## left untouched too.
  lexbase.open(self, input)
  self.filename = filename
  self.a = ""
  self.rawStringLiterals = rawStringLiterals

proc close*(self: var JsonParser) {.inline.} =
  ## closes the parser `self` and its associated input stream.
  lexbase.close(self)

proc getInt*(self: JsonParser): BiggestInt {.inline.} =
  ## returns the number for the event: `jsonInt`
  assert(self.kind == jsonInt)
  return parseBiggestInt(self.a)

proc getFloat*(self: JsonParser): float {.inline.} =
  ## returns the number for the event: `jsonFloat`
  assert(self.kind == jsonFloat)
  return parseFloat(self.a)

proc kind*(self: JsonParser): JsonEventKind {.inline.} =
  ## returns the current event type for the JSON parser
  return self.kind

proc getColumn*(self: JsonParser): int {.inline.} =
  ## get the current column the parser has arrived at.
  result = getColNumber(self, self.bufpos)

proc getLine*(self: JsonParser): int {.inline.} =
  ## get the current line the parser has arrived at.
  result = self.lineNumber

proc getFilename*(self: JsonParser): string {.inline.} =
  ## get the filename of the file that the parser processes.
  result = self.filename

proc parseString(self: var JsonParser): TokenId =
  result = tiString
  var pos = self.bufpos + 1
  if self.rawStringLiterals:
    add(self.a, '"')
  while true:
    case self.buf[pos]
    of '\0':
      self.err = errQuoteExpected
      result = tiError
      break
    of '"':
      if self.rawStringLiterals:
        add(self.a, '"')
      inc(pos)
      break
    of '\\':
      if self.rawStringLiterals:
        add(self.a, '\\')
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

proc skip(self: var JsonParser) =
  var pos = self.bufpos
  while true:
    case self.buf[pos]
    of '/':
      if self.buf[pos+1] == '/':
        # skip line comment:
        inc(pos, 2)
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
      elif self.buf[pos+1] == '*':
        # skip long comment:
        inc(pos, 2)
        while true:
          case self.buf[pos]
          of '\0':
            self.err = errEOC_Expected
            break
          of '\c':
            pos = lexbase.handleCR(self, pos)
          of '\L':
            pos = lexbase.handleLF(self, pos)
          of '*':
            inc(pos)
            if self.buf[pos] == '/':
              inc(pos)
              break
          else:
            inc(pos)
      else:
        break
    of ' ', '\t':
      inc(pos)
    of '\c':
      pos = lexbase.handleCR(self, pos)
    of '\L':
      pos = lexbase.handleLF(self, pos)
    else:
      break
  self.bufpos = pos

proc parseNumber(self: var JsonParser) =
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

proc parseName(self: var JsonParser) =
  var pos = self.bufpos
  if self.buf[pos] in IdentStartChars:
    while self.buf[pos] in IdentChars:
      add(self.a, self.buf[pos])
      inc(pos)
  self.bufpos = pos

proc getTok*(self: var JsonParser): TokenId =
  setLen(self.a, 0)
  skip(self) # skip whitespace, comments
  case self.buf[self.bufpos]
  of '-', '.', '0'..'9':
    parseNumber(self)
    if {'.', 'e', 'E'} in self.a:
      result = tiFloat
    else:
      result = tiInt
  of '"':
    result = parseString(self)
  of '[':
    inc(self.bufpos)
    result = tiBracketLe
  of '{':
    inc(self.bufpos)
    result = tiCurlyLe
  of ']':
    inc(self.bufpos)
    result = tiBracketRi
  of '}':
    inc(self.bufpos)
    result = tiCurlyRi
  of ',':
    inc(self.bufpos)
    result = tiComma
  of ':':
    inc(self.bufpos)
    result = tiColon
  of '\0':
    result = tiEnd
  of 'a'..'z', 'A'..'Z', '_':
    parseName(self)
    case self.a
    else: result = tiString
  else:
    inc(self.bufpos)
    result = tiError
  self.tok = result

proc newJString*(s: string): JsonNode =
  ## Creates a new `JString JsonNode`.
  result = JsonNode(kind: JString, str: s)

proc newJRawNumber(s: string): JsonNode =
  ## Creates a "raw JS number", that is a number that does not
  ## fit into Nim's `BiggestInt` field. This is really a `JString`
  ## with the additional information that it should be converted back
  ## to the string representation without the quotes.
  result = JsonNode(kind: JString, str: s, isUnquoted: true)

proc newJStringMove(s: string): JsonNode =
  result = JsonNode(kind: JString)
  shallowCopy(result.str, s)

proc newJInt*(n: BiggestInt): JsonNode =
  ## Creates a new `JInt JsonNode`.
  result = JsonNode(kind: JInt, num: n)

proc newJFloat*(n: float): JsonNode =
  ## Creates a new `JFloat JsonNode`.
  result = JsonNode(kind: JFloat, fnum: n)

proc newJObject*(): JsonNode =
  ## Creates a new `JObject JsonNode`
  result = JsonNode(kind: JObject, fields: initOrderedTable[string, JsonNode](2))

proc newJArray*(): JsonNode =
  ## Creates a new `JArray JsonNode`
  result = JsonNode(kind: JArray, elems: @[])

proc getStr*(n: JsonNode, default: string = ""): string =
  ## Retrieves the string value of a `JString JsonNode`.
  ##
  ## Returns `default` if `n` is not a `JString`, or if `n` is nil.
  if n.isNil or n.kind != JString: return default
  else: return n.str

proc getInt*(n: JsonNode, default: int = 0): int =
  ## Retrieves the int value of a `JInt JsonNode`.
  ##
  ## Returns `default` if `n` is not a `JInt`, or if `n` is nil.
  if n.isNil or n.kind != JInt: return default
  else: return int(n.num)

proc getBiggestInt*(n: JsonNode, default: BiggestInt = 0): BiggestInt =
  ## Retrieves the BiggestInt value of a `JInt JsonNode`.
  ##
  ## Returns `default` if `n` is not a `JInt`, or if `n` is nil.
  if n.isNil or n.kind != JInt: return default
  else: return n.num

proc getFloat*(n: JsonNode, default: float = 0.0): float =
  ## Retrieves the float value of a `JFloat JsonNode`.
  ##
  ## Returns `default` if `n` is not a `JFloat` or `JInt`, or if `n` is nil.
  if n.isNil: return default
  case n.kind
  of JFloat: return n.fnum
  of JInt: return float(n.num)
  else: return default

iterator items*(node: JsonNode): JsonNode =
  ## Iterator for the items of `node`. `node` has to be a JArray.
  assert node.kind == JArray, ": items() can not iterate a JsonNode of kind " & $node.kind
  for i in items(node.elems):
    yield i

iterator mitems*(node: var JsonNode): var JsonNode =
  ## Iterator for the items of `node`. `node` has to be a JArray. Items can be
  ## modified.
  assert node.kind == JArray, ": mitems() can not iterate a JsonNode of kind " & $node.kind
  for i in mitems(node.elems):
    yield i

iterator pairs*(node: JsonNode): tuple[key: string, val: JsonNode] =
  ## Iterator for the child elements of `node`. `node` has to be a JObject.
  assert node.kind == JObject, ": pairs() can not iterate a JsonNode of kind " & $node.kind
  for key, val in pairs(node.fields):
    yield (key, val)

iterator keys*(node: JsonNode): string =
  ## Iterator for the keys in `node`. `node` has to be a JObject.
  assert node.kind == JObject, ": keys() can not iterate a JsonNode of kind " & $node.kind
  for key in node.fields.keys:
    yield key

iterator mpairs*(node: var JsonNode): tuple[key: string, val: var JsonNode] =
  ## Iterator for the child elements of `node`. `node` has to be a JObject.
  ## Values can be modified
  assert node.kind == JObject, ": mpairs() can not iterate a JsonNode of kind " & $node.kind
  for key, val in mpairs(node.fields):
    yield (key, val)

proc errorMsgExpected*(self: JsonParser, e: string): string =
  ## returns an error message "`e` expected" in the same format as the
  ## other error messages
  result = "$1($2, $3) Error: $4" % [
    self.filename, $getLine(self), $getColumn(self), e & " expected"]

proc raiseParseErr*(p: JsonParser, msg: string) {.noinline, noreturn.} =
  ## raises an `EJsonParsingError` exception.
  raise newException(JsonParsingError, errorMsgExpected(p, msg))

proc eat*(p: var JsonParser, tok: TokenId) =
  if p.tok == tok: discard getTok(p)
  else: raiseParseErr(p, tokToStr[tok])

proc add*(father, child: JsonNode) =
  ## Adds `child` to a JArray node `father`.
  assert father.kind == JArray
  father.elems.add(child)

proc add*(obj: JsonNode, key: string, val: JsonNode) =
  ## Sets a field from a `JObject`.
  assert obj.kind == JObject
  obj.fields[key] = val

proc `[]=`*(obj: JsonNode, key: string, val: JsonNode) {.inline.} =
  ## Sets a field from a `JObject`.
  assert(obj.kind == JObject)
  obj.fields[key] = val

proc hasKey*(node: JsonNode, key: string): bool =
  ## Checks if `key` exists in `node`.
  assert(node.kind == JObject)
  result = node.fields.hasKey(key)

proc parseJson(p: var JsonParser; rawIntegers, rawFloats: bool): JsonNode =
  ## Parses JSON from a JSON Parser `p`.
  case p.tok
  of tiString:
    # we capture 'p.a' here, so we need to give it a fresh buffer afterwards:
    result = newJStringMove(p.a)
    p.a = ""
    discard getTok(p)
  of tiInt:
    if rawIntegers:
      result = newJRawNumber(p.a)
    else:
      try:
        result = newJInt(parseBiggestInt(p.a))
      except ValueError:
        result = newJRawNumber(p.a)
    discard getTok(p)
  of tiFloat:
    if rawFloats:
      result = newJRawNumber(p.a)
    else:
      try:
        result = newJFloat(parseFloat(p.a))
      except ValueError:
        result = newJRawNumber(p.a)
    discard getTok(p)
  of tiCurlyLe:
    result = newJObject()
    discard getTok(p)
    while p.tok != tiCurlyRi:
      if p.tok != tiString:
        raiseParseErr(p, "string literal as key")
      var key = p.a
      discard getTok(p)
      eat(p, tiColon)
      var val = parseJson(p, rawIntegers, rawFloats)
      result[key] = val
      if p.tok != tiComma: break
      discard getTok(p)
    eat(p, tiCurlyRi)
  of tiBracketLe:
    result = newJArray()
    discard getTok(p)
    while p.tok != tiBracketRi:
      result.add(parseJson(p, rawIntegers, rawFloats))
      if p.tok != tiComma: break
      discard getTok(p)
    eat(p, tiBracketRi)
  of tiError, tiCurlyRi, tiBracketRi, tiColon, tiComma, tiEnd:
    raiseParseErr(p, "{")

proc parseJson*(s: Stream, filename: string = ""; rawIntegers = false, rawFloats = false): JsonNode =
  ## Parses from a stream `s` into a `JsonNode`. `filename` is only needed
  ## for nice error messages.
  ## If `s` contains extra data, it will raise `JsonParsingError`.
  ## This closes the stream `s` after it's done.
  ## If `rawIntegers` is true, integer literals will not be converted to a `JInt`
  ## field but kept as raw numbers via `JString`.
  ## If `rawFloats` is true, floating point literals will not be converted to a `JFloat`
  ## field but kept as raw numbers via `JString`.
  var p: JsonParser
  p.open(s, filename)
  try:
    discard getTok(p) # read first token
    result = p.parseJson(rawIntegers, rawFloats)
    eat(p, tiEnd) # check if there is no extra data
  finally:
    p.close()

proc parseJson*(buffer: string; rawIntegers = false, rawFloats = false): JsonNode =
  ## Parses JSON from `buffer`.
  ## If `buffer` contains extra data, it will raise `JsonParsingError`.
  ## If `rawIntegers` is true, integer literals will not be converted to a `JInt`
  ## field but kept as raw numbers via `JString`.
  ## If `rawFloats` is true, floating point literals will not be converted to a `JFloat`
  ## field but kept as raw numbers via `JString`.
  result = parseJson(newStringStream(buffer), "input", rawIntegers, rawFloats)

proc parseFile*(filename: string): JsonNode =
  ## Parses `file` into a `JsonNode`.
  ## If `file` contains extra data, it will raise `JsonParsingError`.
  var stream = newFileStream(filename, fmRead)
  if stream == nil:
    raise newException(IOError, "cannot read from file: " & filename)
  result = parseJson(stream, filename, rawIntegers=false, rawFloats=false)

proc indent(s: var string, i: int) =
  s.add(spaces(i))

proc newIndent(curr, indent: int, ml: bool): int =
  if ml: return curr + indent
  else: return indent

proc nl(s: var string, ml: bool) =
  s.add(if ml: "\n" else: " ")

proc escapeJsonUnquoted*(s: string; result: var string) =
  ## Converts a string `s` to its JSON representation without quotes.
  ## Appends to `result`.
  for c in s:
    case c
    of '\L': result.add("\\n")
    of '\b': result.add("\\b")
    of '\f': result.add("\\f")
    of '\t': result.add("\\t")
    of '\v': result.add("\\u000b")
    of '\r': result.add("\\r")
    of '"': result.add("\\\"")
    of '\0'..'\7': result.add("\\u000" & $ord(c))
    of '\14'..'\31': result.add("\\u00" & toHex(ord(c), 2))
    of '\\': result.add("\\\\")
    else: result.add(c)

proc escapeJsonUnquoted*(s: string): string =
  ## Converts a string `s` to its JSON representation without quotes.
  result = newStringOfCap(s.len + s.len shr 3)
  escapeJsonUnquoted(s, result)

proc escapeJson*(s: string; result: var string) =
  ## Converts a string `s` to its JSON representation with quotes.
  ## Appends to `result`.
  result.add("\"")
  escapeJsonUnquoted(s, result)
  result.add("\"")

proc escapeJson*(s: string): string =
  ## Converts a string `s` to its JSON representation with quotes.
  result = newStringOfCap(s.len + s.len shr 3)
  escapeJson(s, result)

proc toPretty(result: var string, node: JsonNode, indent = 2, ml = true,
              lstArr = false, currIndent = 0) =
  case node.kind
  of JObject:
    if lstArr: result.indent(currIndent) # Indentation
    if node.fields.len > 0:
      result.add("{")
      result.nl(ml) # New line
      var i = 0
      for key, val in pairs(node.fields):
        if i > 0:
          result.add(",")
          result.nl(ml) # New Line
        inc i
        # Need to indent more than {
        result.indent(newIndent(currIndent, indent, ml))
        escapeJson(key, result)
        result.add(": ")
        toPretty(result, val, indent, ml, false,
                 newIndent(currIndent, indent, ml))
      result.nl(ml)
      result.indent(currIndent) # indent the same as {
      result.add("}")
    else:
      result.add("{}")
  of JString:
    if lstArr: result.indent(currIndent)
    if node.isUnquoted:
      result.add node.str
    else:
      escapeJson(node.str, result)
  of JInt:
    if lstArr: result.indent(currIndent)
    result.addInt(node.num)
  of JFloat:
    if lstArr: result.indent(currIndent)
    result.addFloat(node.fnum)
  of JArray:
    if lstArr: result.indent(currIndent)
    if len(node.elems) != 0:
      result.add("[")
      result.nl(ml)
      for i in 0..len(node.elems)-1:
        if i > 0:
          result.add(",")
          result.nl(ml) # New Line
        toPretty(result, node.elems[i], indent, ml,
            true, newIndent(currIndent, indent, ml))
      result.nl(ml)
      result.indent(currIndent)
      result.add("]")
    else: result.add("[]")

proc pretty*(node: JsonNode, indent = 2): string =
  ## Returns a JSON Representation of `node`, with indentation and
  ## on multiple lines.
  ##
  ## Similar to prettyprint in Python.
  runnableExamples:
    let j = %* {"name": "Isaac", "books": ["Robot Dreams"],
                "details": {"age": 35, "pi": 3.1415}}
    doAssert pretty(j) == """
{
  "name": "Isaac",
  "books": [
    "Robot Dreams"
  ],
  "details": {
    "age": 35,
    "pi": 3.1415
  }
}"""
  result = ""
  toPretty(result, node, indent)

proc toUgly*(result: var string, node: JsonNode) =
  ## Converts `node` to its JSON Representation, without
  ## regard for human readability. Meant to improve `$` string
  ## conversion performance.
  ##
  ## JSON representation is stored in the passed `result`
  ##
  ## This provides higher efficiency than the `pretty` procedure as it
  ## does **not** attempt to format the resulting JSON to make it human readable.
  var comma = false
  case node.kind:
  of JArray:
    result.add "["
    for child in node.elems:
      if comma: result.add ","
      else: comma = true
      result.toUgly child
    result.add "]"
  of JObject:
    result.add "{"
    for key, value in pairs(node.fields):
      if comma: result.add ","
      else: comma = true
      key.escapeJson(result)
      result.add ":"
      result.toUgly value
    result.add "}"
  of JString:
    if node.isUnquoted:
      result.add node.str
    else:
      node.str.escapeJson(result)
  of JInt:
    result.addInt(node.num)
  of JFloat:
    result.addFloat(node.fnum)

proc len*(n: JsonNode): int =
  ## If `n` is a `JArray`, it returns the number of elements.
  ## If `n` is a `JObject`, it returns the number of pairs.
  ## Else it returns 0.
  case n.kind
  of JArray: result = n.elems.len
  of JObject: result = n.fields.len
  else: discard

proc `[]`*(node: JsonNode, name: string): JsonNode {.inline.} =
  ## Gets a field from a `JObject`, which must not be nil.
  ## If the value at `name` does not exist, raises KeyError.
  assert(not isNil(node))
  assert(node.kind == JObject)
  when defined(nimJsonGet):
    if not node.fields.hasKey(name): return nil
  result = node.fields[name]

proc `[]`*(node: JsonNode, index: int): JsonNode {.inline.} =
  ## Gets the node at `index` in an Array. Result is undefined if `index`
  ## is out of bounds, but as long as array bound checks are enabled it will
  ## result in an exception.
  assert(not isNil(node))
  assert(node.kind == JArray)
  return node.elems[index]

proc `[]`*(node: JsonNode, index: BackwardsIndex): JsonNode {.inline.} =
  ## Gets the node at `array.len-i` in an array through the `^` operator.
  ##
  ## i.e. `j[^i]` is a shortcut for `j[j.len-i]`.
  runnableExamples:
    let
      j = parseJson("[1,2,3,4,5]")

    doAssert j[^1].getInt == 5
    doAssert j[^2].getInt == 4

  `[]`(node, node.len - int(index))

proc `$`*(node: JsonNode): string =
  ## Converts `node` to its JSON Representation on one line.
  result = newStringOfCap(node.len shl 1)
  toUgly(result, node)
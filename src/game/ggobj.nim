import std/[tables, strutils]

type
  GGNodeKind* = enum ## possible JSON node types
    GGNull,
    GGInt,
    GGFloat,
    GGString,
    GGObject,
    GGArray
  GGNode* = ref GGNodeObj
  GGNodeObj* {.acyclic.} = object
    case kind*: GGNodeKind
    of GGString:
      str*: string
    of GGInt:
      num*: BiggestInt
    of GGFloat:
      fnum*: float
    of GGNull:
      nil
    of GGObject:
      fields*: OrderedTable[string, GGNode]
    of GGArray:
      elems*: seq[GGNode]

proc newGGString*(s: string): GGNode =
  result = GGNode(kind: GGString, str: s)

proc newGGInt*(i: BiggestInt): GGNode =
  result = GGNode(kind: GGInt, num: i)

proc newGGFloat*(f: float): GGNode =
  result = GGNode(kind: GGFloat, fnum: f)

proc newGGNull*(): GGNode =
  result = GGNode(kind: GGNull)

proc newGGObject*(): GGNode =
  result = GGNode(kind: GGObject, fields: initOrderedTable[string, GGNode](2))

proc newGGArray*(): GGNode =
  result = GGNode(kind: GGArray, elems: @[])

proc toInt*(self: GGNode): int =
  case self.kind:
  of GGInt: self.num.int
  of GGFloat: self.fnum.int
  else: 0

proc toFloat*(self: GGNode): float =
  case self.kind:
  of GGInt: self.num.float
  of GGFloat: self.fnum.float
  else: 0

proc indent(s: var string, i: int) =
  s.add(spaces(i))

proc newIndent(curr, indent: int, ml: bool): int =
  if ml: return curr + indent
  else: return indent

proc nl(s: var string, ml: bool) =
  s.add(if ml: "\n" else: " ")

proc toPretty(result: var string, node: GGNode, indent = 2, ml = true,
              lstArr = false, currIndent = 0) =
  case node.kind
  of GGNull:
    result.add("null")
  of GGObject:
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
        result.add(": ")
        toPretty(result, val, indent, ml, false,
                 newIndent(currIndent, indent, ml))
      result.nl(ml)
      result.indent(currIndent) # indent the same as {
      result.add("}")
    else:
      result.add("{}")
  of GGString:
    if lstArr: result.indent(currIndent)
    result.add node.str
  of GGInt:
    if lstArr: result.indent(currIndent)
    result.addInt(node.num)
  of GGFloat:
    if lstArr: result.indent(currIndent)
    result.addFloat(node.fnum)
  of GGArray:
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

proc pretty*(node: GGNode, indent = 2): string =
  result = ""
  toPretty(result, node, indent)
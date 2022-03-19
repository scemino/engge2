import std/[macros, tables]
import ggobj

proc add*(father, child: GGNode) =
  assert father.kind == GGArray
  father.elems.add(child)

proc add*(obj: GGNode, key: string, val: GGNode) =
  assert obj.kind == GGObject
  obj.fields[key] = val

proc toGG*(n: int): GGNode =
  GGNode(kind: GGInt, num: n)

proc toGG*(s: string): GGNode =
  GGNode(kind: GGString, str: s)

proc toGG*(f: float): GGNode =
  GGNode(kind: GGFloat, fnum: f)

proc toGG*(keyVals: openArray[tuple[key: string, val: GGNode]]): GGNode =
  if keyVals.len == 0: return newGGArray()
  result = newGGObject()
  for key, val in items(keyVals): result.fields[key] = val

template toGG*(j: GGNode): GGNode = j

proc toGG*[T](elements: openArray[T]): GGNode =
  result = newGGArray()
  for elem in elements: result.add(toGG elem)

proc toGG*[T](table: Table[string, T]|OrderedTable[string, T]): GGNode =
  result = newGGObject()
  for k, v in table: result[k] = v.toGG

proc toGG*[T: object](o: T): GGNode =
  result = newGGObject()
  for k, v in o.fieldPairs: result[k] = v.toGG

proc toGGImpl(x: NimNode): NimNode =
  case x.kind
  of nnkBracket: # array
    if x.len == 0: return newCall(bindSym"newGGArray")
    result = newNimNode(nnkBracket)
    for i in 0 ..< x.len:
      result.add(toGGImpl(x[i]))
    result = newCall(bindSym"toGG", result)
  of nnkTableConstr: # object
    if x.len == 0: return newCall(bindSym"newGGObject")
    result = newNimNode(nnkTableConstr)
    for i in 0 ..< x.len:
      x[i].expectKind nnkExprColonExpr
      result.add newTree(nnkExprColonExpr, x[i][0], toGGImpl(x[i][1]))
    result = newCall(bindSym"toGG", result)
  of nnkCurly: # empty object
    x.expectLen(0)
    result = newCall(bindSym"newGGObject")
  of nnkNilLit:
    result = newCall(bindSym"newGGNull")
  of nnkPar:
    if x.len == 1: result = toGGImpl(x[0])
    else: result = newCall(bindSym"toGG", x)
  else:
    result = newCall(bindSym"toGG", x)

macro toGGobj*(x: untyped): untyped =
  result = toGGImpl(x)
import std/strformat
import std/logging
import std/streams
import std/parseutils
import std/tables
import ggpackmanager

type TextDb = object
  texts: OrderedTable[int, string]

var gTextDb: TextDb

proc parseTsv*(stream: Stream): OrderedTable[int, string] =
  for line in stream.lines:
    var id: int
    var pos = parseInt(line, id, 0)
    if pos != 0:
      pos += skipWhitespace(line, pos)
      result[id] = line.substr(pos)

proc readTsvFromPack*(entry: string): OrderedTable[int, string] =
  parseTsv(newStringStream(gGGPackMgr.loadStream(entry).readAll))

proc read(self: var TextDb, entry: string) =
  self.texts = readTsvFromPack(entry)

proc getText(self: TextDb, id: int): string =
  if self.texts.contains(id):
    result = self.texts[id]
  else:
    result = fmt"Text {id} not found"
    error fmt"Text {id} not found in {self.texts}"

proc initTextDb*() =
  gTextDb.read("ThimbleweedText_en.tsv")

proc getText*(id: int): string =
  gTextDb.getText(id)

proc getText*(text: string): string =
  if text.len > 0:
    if text[0] == '@':
      var id: int
      discard parseInt(text, id, 1)
      return getText(id)
    elif text[0] == '^':
      return text.substr(1)
  return text

when isMainModule:
  var content = "text_id	en\n90000	en\n98000	English\n"
  var ss = newStringStream(content)
  var t = parseTsv(ss)
  echo t
  doAssert t[90000]=="en"
  doAssert t[98000]=="English"
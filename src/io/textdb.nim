import std/strformat
import std/logging
import std/streams
import std/parseutils
import std/tables
import std/strutils
import sqnim
import ggpackmanager
import ../game/prefs
import ../script/vm
import ../script/squtils

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
    if result.endsWith("#M") or result.endsWith("#F"):
      result = result[0..^3]
    # replace \" by "
    result = result.replace("\\\"", "\"")
  else:
    result = fmt"Text {id} not found"
    error fmt"Text {id} not found in {self.texts}"

proc initTextDb*() =
  let lang = prefs(Lang)
  gTextDb.read(fmt"ThimbleweedText_{lang}.tsv")

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
    elif text[0] == '$':
      var txt: string
      let top = sq_gettop(gVm.v)
      sq_pushroottable(gVm.v)
      let code = "return " & text[1..^1]
      if SQ_FAILED(sq_compilebuffer(gVm.v, code.cstring, code.len, "execCode", SQTrue)):
        error fmt"Error executing code {code}"
      else:
        sq_push(gVm.v, -2)
        # call
        if SQ_FAILED(sq_call(gVm.v, 1, SQTrue, SQTrue)):
          error fmt"Error calling code {code}"
        else:
          discard get(gVm.v, -1, txt)
          sq_settop(gVm.v, top)
          return getText(txt)
  return text

when isMainModule:
  var content = "text_id	en\n90000	en\n98000	English\n"
  var ss = newStringStream(content)
  var t = parseTsv(ss)
  echo t
  doAssert t[90000]=="en"
  doAssert t[98000]=="English"
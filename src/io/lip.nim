import std/streams
import std/parseutils
import ggpackmanager

type Lip* = object
  ## This contains the lip animation for a specific text.
  ## 
  ## A lip animation contains a list of moth shape at a specific time.
  ## You can see https://github.com/DanielSWolf/rhubarb-lip-sync to
  ## have additional information about the mouth shapes.
  items: seq[tuple[time: float, letter: char]]

proc parseLip(stream: Stream): seq[tuple[time: float, letter: char]] =
  for line in stream.lines:
    var time: float
    var pos = parseFloat(line, time, 0)
    pos += skipWhitespace(line, pos)
    result.add (time, line.substr(pos, pos + 1)[0])

proc readLipFromPack(entry: string): seq[tuple[time: float, letter: char]] =
  parseLip(newStringStream(gGGPackMgr.loadStream(entry).readAll))

proc newLip*(stream: Stream): Lip =
  ## Creates a lip animation from a stream.
  Lip(items: parseLip(stream))

proc newLip*(entry: string): Lip =
  ## Creates a lip animation from an entry in a ggpack file.
  Lip(items: readLipFromPack(entry))

proc letter*(self: Lip, time: float): char =
  ## Gets the letter corresponding to a mouth shape at a spcific time.
  if self.items.len == 0:
    return 'A'
  else:
    for i in 0..<self.items.len-1:
      if time < self.items[i + 1].time:
        return self.items[i].letter
    self.items[^1].letter

when isMainModule:
  var content = """0.00	X
0.03	C
0.10	B
0.16	F
0.23	B
"""
  var ss = newStringStream(content)
  var lip = newLip(ss)
  doAssert lip.letter(0.00) == 'X'
  doAssert lip.letter(0.01) == 'X'
  doAssert lip.letter(0.03) == 'C'
  doAssert lip.letter(0.09) == 'C'
  doAssert lip.letter(0.10) == 'B'
  doAssert lip.letter(0.11) == 'B'
  doAssert lip.letter(0.15) == 'B'
  doAssert lip.letter(0.17) == 'F'
  doAssert lip.letter(0.23) == 'B'
  doAssert lip.letter(42.0) == 'B'

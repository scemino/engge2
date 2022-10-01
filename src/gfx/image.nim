import glm
import stb_image
import std/streams
import ../io/ggpackmanager

type Image* = object
  filename*: string
  width*, height*, channels*: int
  data*: seq[byte]

proc newImage*(filename: string): Image =
  let fs = gGGPackMgr.loadStream(filename)
  let str = fs.readAll
  let bytes = newSeq[byte](str.len)
  copyMem(bytes[0].unsafeAddr, str[0].unsafeAddr, str.len)
  result = Image(filename: filename, channels: 4)
  var channels: int
  result.data = loadFromMemory(bytes, result.width, result.height, channels, RGBA)

proc newImage*(data: seq[byte]): Image = 
  result.data = loadFromMemory(data, result.width, result.height, result.channels, RGBA)

proc newImage*(width, height, channels: int, data: seq[byte]): Image =
  result.width = width
  result.height = height
  result.channels = channels
  result.data = data

proc newImage*(size: Vec2i, channels: int, data: seq[byte]): Image =
  newImage(size.x, size.y, channels, data)

proc writePNG*(self: Image, filename: string) = 
  discard writePNG(filename, self.width, self.height, self.channels, self.data)

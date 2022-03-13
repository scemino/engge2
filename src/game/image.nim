import stb_image/read as stbi
import std/streams
import ../io/ggpackmanager

type Image* = object
  filename*: string
  width*, height*, channels*: int
  data*: seq[byte]

proc newImage*(filename: string): Image =
  let fs = ggpackMgr.loadStream(filename)
  let str = fs.readAll
  let bytes = newSeq[byte](str.len)
  copyMem(bytes[0].unsafeAddr, str[0].unsafeAddr, str.len)
  result.filename = filename
  result.data = stbi.loadFromMemory(bytes, result.width, result.height, result.channels, stbi.RGBA)

proc newImage*(data: seq[byte]): Image = 
  result.data = stbi.loadFromMemory(data, result.width, result.height, result.channels, stbi.RGBA)

proc newImage*(width, height, channels: int, data: seq[byte]): Image =
  result.width = width
  result.height = height
  result.channels = channels
  result.data = data
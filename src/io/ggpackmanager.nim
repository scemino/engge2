import std/[streams, os, tables, json, sequtils, logging, strutils]
import nimyggpack

type
  GGPackManager = ref object of RootObj
  GGPackFileSystemManager = ref object of GGPackManager
    root: string
    directories: seq[string] # directories where to search files
  GGPackFileManager = ref object of GGPackManager
    path: string
    ggpack: GGPackDecoder

proc newGGPackFileSystemManager*(root: string, directories: varargs[string]): GGPackFileSystemManager =
  new(result)
  result.root = root
  result.directories = directories.toSeq
  
var gGGPackMgr*: GGPackManager

method loadStream*(self: GGPackManager, path: string): Stream {.base.} =
  # override this base method
  raise newException(CatchableError, "Method without implementation override")

method listFiles*(self: GGPackManager): seq[string] {.base.} =
  # override this base method
  raise newException(CatchableError, "Method without implementation override")

method assetExists*(self: GGPackManager, entry: string): bool {.base.} =
  # override this base method
  raise newException(CatchableError, "Method without implementation override")

method loadStream*(self: GGPackFileSystemManager, path: string): Stream =
  for dir in self.directories:
    let fullPath = joinPath(self.root, dir, path)
    if fileExists(fullPath):
      return newFileStream(fullPath)
  raise newException(IOError, "Path not found")

method listFiles*(self: GGPackFileSystemManager): seq[string] =
  for dir in self.directories:
    let fullPath = joinPath(self.root, dir) & "/*"
    info "fullPath: " & fullPath
    for file in os.walkFiles(fullPath):
      result.add(file)

method assetExists*(self: GGPackFileSystemManager, entry: string): bool =
  for dir in self.directories:
    let fullPath = joinPath(self.root, dir) & "/*"
    for file in os.walkFiles(fullPath):
      var (_, name, _) = splitFile(file)
      if cmpIgnoreCase(name, entry) == 0:
        return true
  false

proc newGGPackFileManager*(path: string): GGPackFileManager =
  new(result)
  result.path = path
  result.ggpack = newGGPackDecoder(newFileStream(path), xorKeys["56ad"])

method loadStream(self: GGPackFileManager, path: string): Stream =
  var (_, _, ext) = splitFile(path)
  if ext == ".wimpy":
    newStringStream(pretty(self.ggpack.extractTable(path)))
  else:
    self.ggpack.extract(path)

method listFiles*(self: GGPackFileManager): seq[string] =
  for (entry,_) in self.ggpack.entries.pairs:
    result.add("ggpack://" & self.path & "/" & entry)

method assetExists*(self: GGPackFileManager, entry: string): bool =
  self.ggpack.entries.contains(entry)
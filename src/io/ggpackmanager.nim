import std/[streams, os, tables, json, sequtils, logging, strutils, strformat]
import nimyggpack

type
  GGPackManager = ref object of RootObj
  GGPackFileSystemManager = ref object of GGPackManager
    root: string
    directories: seq[string] # directories where to search files
  GGPackFileManager = ref object of GGPackManager
    path: string
    ggpacks: seq[GGPackDecoder]

proc newGGPackFileSystemManager*(root: string, directories: varargs[string]): GGPackFileSystemManager =
  new(result)
  result.root = root
  result.directories = directories.toSeq
  
var gGGPackMgr*: GGPackManager

method loadStream*(self: GGPackManager, path: string): Stream {.base, locks: "unknown".} =
  # override this base method
  raise newException(CatchableError, "Method without implementation override")

method listFiles*(self: GGPackManager): seq[string] {.base, locks: "unknown".} =
  # override this base method
  raise newException(CatchableError, "Method without implementation override")

method assetExists*(self: GGPackManager, entry: string): bool {.base, locks: "unknown".} =
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
  info fmt"Search ggpack in {path.substr(0, path.len-2) & '*'}"
  for file in os.walkFiles(path.substr(0, path.len-2) & '*'):
    info fmt"Add ggpack {file}"
    result.ggpacks.add newGGPackDecoder(newFileStream(file), xorKeys["56ad"])

method loadStream(self: GGPackFileManager, path: string): Stream =
  var entry = path.toLower
  var (_, _, ext) = splitFile(entry)
  for pack in self.ggpacks:
    if pack.entries.contains(entry):
      if ext == ".wimpy":
        return newStringStream(pretty(pack.extractTable(entry)))
      else:
        return pack.extract(entry)
  error fmt"{entry} not found"
  for pack in self.ggpacks:
    error pack.entries

method listFiles*(self: GGPackFileManager): seq[string] =
  for pack in self.ggpacks:
    for (entry,_) in pack.entries.pairs:
      result.add("ggpack://" & self.path & "/" & entry)

method assetExists*(self: GGPackFileManager, path: string): bool =
  var entry = path.toLower
  for pack in self.ggpacks:
    if pack.entries.contains(entry):
      return true

proc loadString*(self: GGPackManager, entry: string): string =
  self.loadStream(entry).readAll

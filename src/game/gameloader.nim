import std/json

type
  GameLoader* = ref object of RootObj

var
  gGameLoader*: GameLoader
  gAutoSave*: bool
  gAllowSaveGames* = true

method load*(self: GameLoader, json: JsonNode) {.base.} =
  discard

method save*(self: GameLoader, index: int) {.base.} =
  discard

proc loadGame*(json: JsonNode) =
  gGameLoader.load(json)

proc saveGame*(index: int) =
  gGameLoader.save(index)
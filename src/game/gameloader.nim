import std/json

type
  GameLoader* = ref object of RootObj

var gGameLoader*: GameLoader

method load*(self: GameLoader, json: JsonNode) {.base.} =
  discard

method save*(self: GameLoader, json: JsonNode) {.base.} =
  discard

proc loadGame*(json: JsonNode) =
  gGameLoader.load(json)

proc saveGame*(json: JsonNode) =
  gGameLoader.save(json)
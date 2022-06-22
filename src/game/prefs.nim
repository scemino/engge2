import std/os
import ../io/json

const
  PreferencesFileName = "Prefs.json"
type
  TempPref = object
    gameSpeedFactor*: float32
  Preferences* = object
    node*: JsonNode
    tmp*: TempPref

proc init*(self: var Preferences) =
  self.tmp = TempPref(gameSpeedFactor: 1'f32)
  if fileExists(PreferencesFileName):
    self.node = parseFile(PreferencesFileName)
  else:
    self.node = newJObject()

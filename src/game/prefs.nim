import std/os
import ../io/json

const
  PreferencesFileName = "Prefs.json"
type
  Preferences* = object
    node*: JsonNode

proc init*(self: var Preferences) =
  if fileExists(PreferencesFileName):
    self.node = parseFile(PreferencesFileName)
  else:
    self.node = newJObject()

import std/os
import std/strutils
import std/strformat
import ../io/json

const
  PreferencesFileName = "Prefs.json"
  Lang* = "language"
  LangDefValue* = "en"
type
  TempPref = object
    gameSpeedFactor*: float32
    forceTalkieText*: bool
  Preferences* = object
    node*: JsonNode
    tmp*: TempPref
var
  gPrefs = Preferences()

proc init(self: var Preferences) =
  self.tmp = TempPref(gameSpeedFactor: 1'f32)
  if fileExists(PreferencesFileName):
    self.node = parseFile(PreferencesFileName)
  else:
    self.node = newJObject()

proc initPrefs*() =
  gPrefs.init()

proc tmpPrefs*(): var TempPref =
  gPrefs.tmp

proc prefs*(name, default: string): string =
  if gPrefs.node.hasKey(name): gPrefs.node[name].str else: default

proc prefsAsJson*(name: string): JsonNode =
  gPrefs.node[name]

proc hasPrefs*(name: string): bool =
  gPrefs.node.hasKey(name)

proc getKey*(path: string): string =
  result = path
  let (_, name, ext) = splitFile(path)
  if name.endsWith("_en"):
    let lang = prefs(Lang, LangDefValue)
    result = fmt"{name.substr(0, name.len - 4)}_{lang}{ext}"    
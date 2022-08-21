import std/os
import std/strutils
import std/strformat
import ../io/json

const
  PreferencesFileName = "Prefs.json"
  Lang* = "language"
  LangDefValue* = "en"
  UiBackingAlpha = "uiBackingAlpha"
  InvertVerbHighlight* = "invertVerbHighlight"
  InvertVerbHighlightDefValue* = false
  RetroVerbs* = "retroVerbs"
  RetroVerbsDefValue* = false
  RetroFonts* = "retroFonts"
  RetroFontsDefValue* = false
  Language* = "language"
  ClassicSentence* = "hudSentence"
  ClassicSentenceDefValue* = false
  Controller* = "controller"
  ControllerDefValue* = false
  ScrollSyncCursor* = "controllerScollLockCursor"
  ScrollSyncCursorDefValue* = false
  DisplayText* = "talkiesShowText"
  DisplayTextDefValue* = true
  HearVoice* = "talkiesHearVoice"
  HearVoiceDefValue* = true
  SayLineSpeed* = "sayLineSpeed"
  SayLineSpeedDefValue* = 0.8'f32
  SayLineBaseTime = "sayLineBaseTime"
  SayLineCharTime = "sayLineCharTime"
  SayLineMinTime = "sayLineMinTime"
  ToiletPaperOver* = "toiletPaperOver"
  ToiletPaperOverDefValue* = false
  AnnoyingInJokes* = "annoyingInJokes"
  AnnoyingInJokesDefValue* = false
  SafeArea = "safeScale"
  Fullscreen* = "windowFullscreen"
  FullscreenDefValue* = false
  RightClickSkipsDialog = "rightClickSkipsDialog"
  KeySkipText = "keySkipText"
  KeySelect1 = "keySelect1"
  KeySelect2 = "keySelect2"
  KeySelect3 = "keySelect3"
  KeySelect4 = "keySelect4"
  KeySelect5 = "keySelect5"
  KeySelect6 = "keySelect6"
  KeySelectPrev = "keySelectPrev"
  KeySelectNext = "keySelectNext"
  VolumeMusic* = "volumeMusic"
  VolumeSound* = "volumeSound"
  VolumeTalkies* = "volumeTalkies"
  ParrotDialogChoices = "parrotDialogChoices"
  ScrollInventorySensitivity = "scrollInventorySensitivity"
  ShowUnknownActorIcons = "showUnknownActorIcons"
  DoubleClickDefaultVerb = "doubleClickDefaultVerb"
  AlwaysFastWalk = "alwaysFastWalk"
  SaveGameName = "saveGameName"
  SaveGamePath = "saveGamePath"
  HudRetroScale = "hudRetroScale"
  HudRetroScaleDefValue = 0.8'f32
  HudModernScale = "hudModernScale"
  HudModernScaleDefValue = 0.025'f32
  
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

proc savePrefs*() =
  writeFile PreferencesFileName, pretty(gPrefs.node, 2)

proc prefs*(name, default: string): string =
  if gPrefs.node.hasKey(name): gPrefs.node[name].str else: default

proc prefs*(name: string, default: float32): float32 =
  if gPrefs.node.hasKey(name): gPrefs.node[name].getFloat().float32 else: default

proc prefs*(name: string, default: bool): bool =
  if gPrefs.node.hasKey(name): gPrefs.node[name].getInt() != 0 else: default

proc setPrefs*(name, value: string) =
  gPrefs.node[name] = newJString(value)
  savePrefs()

proc setPrefs*(name: string, value: float32) =
  gPrefs.node[name] = newJFloat(value)
  savePrefs()

proc setPrefs*(name: string, value: bool) =
  gPrefs.node[name] = newJInt(if value: 1 else: 0)
  savePrefs()

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
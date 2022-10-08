import std/os
import std/json
import std/logging
import std/strformat
import nimyggpack

const AchievementsFilename = "Save.dat"

var gAchievements: JsonNode

proc loadAchievements*() =
  if fileExists(AchievementsFilename):
    gAchievements = loadAchievements(AchievementsFilename)
  else:
    gAchievements = newJObject()

proc saveAchievements() =
  saveAchievements(AchievementsFilename, gAchievements)

proc hasPrivPref*(name: string): bool =
  gAchievements.hasKey(name)

proc getPrivPref*(name: string, defValue: int): int =
  if gAchievements.hasKey(name):
    result = gAchievements[name].getInt()
  else:
    result = defValue

proc getPrivPref*(name: string, defValue: string): string =
  if gAchievements.hasKey(name):
    result = gAchievements[name].getStr()
  else:
    result = defValue

proc privPref*(name: string, value: int) =
  debug fmt"setPrivatePreference({name},{value})"
  gAchievements[name] = newJInt(value)
  saveAchievements()

proc privPref*(name: string, value: string) =
  debug fmt"setPrivatePreference({name},{value})"
  gAchievements[name] = newJString(value)
  saveAchievements()

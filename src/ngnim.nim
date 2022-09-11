import std/[logging, os, strformat]
import sys/[app, input]
import game/engine
import game/inputmap
import game/states/state
import game/states/enginestate
import game/states/dlgstate
import scenegraph/startscreen

when defined(Windows):
  {.passL: "-static".}

const
  AppName = "engge II"
  PackageName = "ThimbleweedPark.ggpack1"

var
  oldKeys: seq[InputKey]

proc onKey(key: InputKey, scancode: int32, action: InputAction, mods: InputModifierKey) =
  if action == iaPressed:
    if not oldKeys.contains(key):
      oldKeys.add key
      execCmd(Input(key: key, modf: mods))
  else:
    let i = oldKeys.find(key)
    if i != -1:
      oldKeys.del i

proc render() =
  updateState()

proc main() =
  app.init(title = AppName)
  app.setKeyCallback(onKey)

  if fileExists(PackageName):
    pushState newEngineState(PackageName, AppName)
    pushState newDlgState(newStartScreen())
    app.run(render)
  else:
    error fmt"{PackageName} not found"

main()

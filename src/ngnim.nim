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

proc onKey(key: InputKey, scancode: int32, action: InputAction,
    mods: InputModifierKey) =
  execCmd(Input(key: key, modf: mods))

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

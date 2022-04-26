import std/[logging, os]
import sys/[app, input]
import game/engine
import script/vm
import script/script
import io/ggpackmanager
import io/textdb
import game/eventmanager
import game/gameeventmanager
import game/resmanager

proc onKey(key: InputKey, scancode: int32, action: InputAction,
    mods: InputModifierKey) =
  if key == Escape:
    app.appQuit()

proc render() =
  gEngine.render()

proc runVm() =
  var vm = vm.newVM()
  discard newEngine(vm.v)
  register_gameconstants(vm.v)
  register_gamelib(vm.v)
  vm.execNutFile("ng.nut")

proc main() =
  addHandler(newConsoleLogger())
  addHandler(newRollingFileLogger("errors.log", levelThreshold=lvlError))
  addHandler(newRollingFileLogger("ng.log"))
  info("# Welcome to ngnim")

  app.init(title = "ngnim")
  app.setKeyCallback(onKey)

  if fileExists("ThimbleweedPark.ggpack1"):
    gGGPackMgr = newGGPackFileManager("ThimbleweedPark.ggpack1")
    gResMgr = newResManager()
    gEventMgr = newGameEventManager()
    initTextDb()
    runVm()
    app.run(render)
  else:
    error "ThimbleweedPark.ggpack1 not found"

main()

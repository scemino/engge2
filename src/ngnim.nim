import std/[logging, os]
import sys/[app, input]
import game/engine
import script/vm
import script/script
import io/ggpackmanager

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
  addHandler(newFileLogger("log.txt"))
  info("# Welcome to ngnim")

  app.init(title = "ngnim")
  app.setKeyCallback(onKey)

  if fileExists("ThimbleweedPark.ggpack1"):
    gGGPackMgr = newGGPackFileManager("ThimbleweedPark.ggpack1")
    runVm()
    app.run(render)
  else:
    error "ThimbleweedPark.ggpack1 not found"

main()

import std/[logging, os]
import sqnim
import sys/[app, input]
import game/[engine, vm, script]
import io/ggpackmanager

proc onKey(key: InputKey, scancode: int32, action: InputAction,
    mods: InputModifierKey) =
  if key == Escape:
    app.appQuit()

proc render() =
  gEngine.render()

proc main() =
  addHandler(newConsoleLogger())
  addHandler(newFileLogger("log.txt"))
  info("# Welcome to ngnim")

  app.init(title = "ngnim")
  app.setKeyCallback(onKey)

  if fileExists("ThimbleweedPark.ggpack1"):
    gGGPackMgr = newGGPackFileManager("ThimbleweedPark.ggpack1")
    discard newEngine()
    var vm = vm.newVM()
    vm.v.regConsts(@[("FALSE", 0), ("TRUE", 1)])
    register_gamelib(vm.v)
    vm.execNutFile("ng.nut")

    app.run(render)
  else:
    error "ThimbleweedPark.ggpack1 not found"

main()

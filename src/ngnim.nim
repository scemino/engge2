import std/[logging, os]
import sys/[app, input]
import sqnim
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

  sq_pushroottable(vm.v)

  sqstd_register_stringlib(vm.v)
  sqstd_register_iolib(vm.v)
  register_gameconstants(vm.v)
  register_gamelib(vm.v)

  vm.v.execNutEntry("Defines.nut")
  if fileExists("ng.nut"):
    info "Booting with ng.nut"
    vm.v.execNutFile("ng.nut")
  else:
    info "Booting with embedded Boot.bnut"
    vm.v.execBnutEntry("Boot.bnut")
    vm.v.execNut("ng", "cameraInRoom(StartScreen)");
  sq_pop(vm.v, 1)

proc main() =
  addHandler(newConsoleLogger())
  addHandler(newRollingFileLogger("errors.log", levelThreshold=lvlError))
  addHandler(newRollingFileLogger("ng.log"))
  info("# Welcome to ngnim")

  app.init(title = "engge II")
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

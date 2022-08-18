import std/[logging, os, strformat, times]
import sys/[app, input]
import sqnim
import game/engine
import script/vm
import script/script
import io/ggpackmanager
import io/textdb
import game/eventmanager
import game/gameeventmanager
import game/prefs
import game/resmanager
import game/gameloader
import game/savegame
import scenegraph/node
import scenegraph/pathnode
import scenegraph/dlgenginetgt
import scenegraph/dialog
import sys/debugtool
import sys/tools

proc onKey(key: InputKey, scancode: int32, action: InputAction,
    mods: InputModifierKey) =
  if key == Escape:
    app.appQuit()

proc render() =
  gEngine.render()

proc runVm() =
  var vm = vm.newVM()
  discard newEngine(vm.v)
  gEngine.dlg.tgt = EngineDialogTarget()
  gEngine.screen.addChild newPathNode()

  sq_pushroottable(vm.v)

  sqstd_register_stringlib(vm.v)
  sqstd_register_mathlib(vm.v)
  sqstd_register_iolib(vm.v)
  register_gameconstants(vm.v)
  register_gamelib(vm.v)

  vm.v.execNutEntry("Defines.nut")
  if fileExists("ng.nut"):
    info "Booting with ng.nut"
    vm.v.execNutFile("ng.nut")
  else:
    info "Booting with embedded Boot.bnut"
    let time = getTime()
    vm.v.execBnutEntry("Boot.bnut")
    let duration = getTime() - time
    info fmt"Boot ended in {duration}"
    vm.v.execNut("ng", "cameraInRoom(StartScreen)")
  sq_pop(vm.v, 1)

proc main() =
  # create loggers
  addHandler(newConsoleLogger())
  addHandler(newRollingFileLogger("errors.log", levelThreshold=lvlWarn))
  addHandler(newRollingFileLogger("ng.log"))
  let consoleTool = newConsoleTool()
  addHandler(newConsoleToolLogger(consoleTool))
  info("# Welcome to ngnim")
  info fmt"Host: {hostCPU} / {hostOS}"
  info fmt"Nim: {NimVersion}"
  addDebugTool(consoleTool)
  addDebugTool(newThreadTool())
  addDebugTool(newSoundTool())
  addDebugTool(newTextureTool())
  addDebugTool(newActorTool())
  addDebugTool(newGeneralTool())
  addDebugTool(newObjectTool())
  addDebugTool(newStackTool())

  # init app
  app.init(title = "engge II")
  app.setKeyCallback(onKey)
  initPrefs()

  # check if we have game assets
  if fileExists("ThimbleweedPark.ggpack1"):
    # then start game
    gGGPackMgr = newGGPackFileManager("ThimbleweedPark.ggpack1")
    gResMgr = newResManager()
    gEventMgr = newGameEventManager()
    gGameLoader = newEngineGameLoader()
    initTextDb()
    runVm()
    app.run(render)
  else:
    error "ThimbleweedPark.ggpack1 not found"

main()

import std/[logging, os, strformat, times]
import sqnim
import state
import ../../script/vm
import ../../script/script
import ../../io/ggpackmanager
import ../../io/textdb
import ../engine
import ../eventmanager
import ../gameeventmanager
import ../prefs
import ../resmanager
import ../gameloader
import ../savegame
import ../inputmap
import ../../scenegraph/node
import ../../scenegraph/dlgenginetgt
import ../../scenegraph/pathnode
import ../../sys/debugtool
import ../../sys/tools


type
  EngineState = ref object of State
    packageName, appName: string

proc newEngineState*(packageName, appName: string): EngineState =
  EngineState(packageName: packageName, appName: appName)

method init*(self: EngineState) =
  # create loggers
  addHandler(newConsoleLogger())
  addHandler(newRollingFileLogger("errors.log", levelThreshold=lvlWarn))
  addHandler(newRollingFileLogger("ng.log"))
  
  let consoleTool = newConsoleTool()
  addHandler(newConsoleToolLogger(consoleTool))
  addDebugTool(consoleTool)
  addDebugTool(newThreadTool())
  addDebugTool(newSoundTool())
  addDebugTool(newTextureTool())
  addDebugTool(newActorTool())
  addDebugTool(newGeneralTool())
  addDebugTool(newObjectTool())
  addDebugTool(newStackTool())

  info fmt"# Welcome to {self.appName}"
  info fmt"Host: {hostCPU} / {hostOS}"
  info fmt"Nim: {NimVersion}"
  
  initPrefs()
  regCmds()

  let key = prefs("key", "56ad")
  gGGPackMgr = newGGPackFileManager(self.packageName, key)
  gResMgr = newResManager()
  gEventMgr = newGameEventManager()
  gGameLoader = newEngineGameLoader()
  initTextDb()
  
  let vm = vm.newVM()
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

method deinit*(self: EngineState) =
  discard

method update*(self: EngineState, elapsed: float) =
  gEngine.update(elapsed)
  gEngine.render()

import std/[logging, os, strformat, times]
import sqnim
import state
import pausestate
import ../actor
import ../engine
import ../cutscene
import ../eventmanager
import ../gameeventmanager
import ../prefs
import ../resmanager
import ../gameloader
import ../savegame
import ../inputmap
import ../inputstate
import ../../script/vm
import ../../script/script
import ../../io/ggpackmanager
import ../../io/textdb
import ../../scenegraph/node
import ../../scenegraph/dlgenginetgt
import ../../scenegraph/nooverride
import ../../sys/debugtool
import ../../sys/tools

type
  EngineState = ref object of State
    packageName, appName: string
    noOverride: NoOverride

proc newEngineState*(packageName, appName: string): EngineState =
  EngineState(packageName: packageName, appName: appName)

method init*(self: EngineState) =
  # create loggers
  addHandler(newConsoleLogger())
  addHandler(newRollingFileLogger("errors.log", levelThreshold=lvlWarn))
  addHandler(newRollingFileLogger("ng.log"))
  
  let consoleTool = newConsoleTool()
  let threadTool = newThreadTool()
  let soundTool = newSoundTool()
  let textureTool = newTextureTool()
  let actorTool = newActorTool()
  let objectTool = newObjectTool()
  let stackTool = newStackTool()
  addHandler(newConsoleToolLogger(consoleTool))
  addDebugTool(consoleTool)
  addDebugTool(threadTool)
  addDebugTool(soundTool)
  addDebugTool(textureTool)
  addDebugTool(actorTool)
  addDebugTool(objectTool)
  addDebugTool(stackTool)
  addDebugTool(newGeneralTool())

  addTool("console", consoleTool.visible.addr)
  addTool("threads", threadTool.visible.addr)
  addTool("sounds", soundTool.visible.addr)
  addTool("textures", textureTool.visible.addr)
  addTool("actors", actorTool.visible.addr)
  addTool("objects", objectTool.visible.addr)
  addTool("stack", stackTool.visible.addr)

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

proc skipCutscene(self: EngineState) =
  let cutscene = cast[Cutscene](gEngine.cutscene)
  if not cutscene.isNil:
    if cutscene.hasOverride:
      cutscene.cutsceneOverride()
    elif self.noOverride.isNil:
      self.noOverride = newNoOverride()
      gEngine.screen.addChild self.noOverride
    else:
      self.noOverride.reset()

method activate*(self: EngineState) =
  gEngine.screen.addChild gInputNode
  regCmdFunc(GameCommand.ToggleDebug, proc () = gGeneralVisible = not gGeneralVisible)
  regCmdFunc(GameCommand.ShowOptions, proc () = showOptions())
  regCmdFunc(GameCommand.PauseGame, proc () = pushState newPauseState())
  regCmdFunc(GameCommand.SkipText, proc () = stopTalking())
  regCmdFunc(GameCommand.SkipCutscene, proc () = self.skipCutscene())

method deactivate*(self: EngineState) =
  unregCmdFunc(GameCommand.PauseGame)
  unregCmdFunc(GameCommand.ShowOptions)
  unregCmdFunc(GameCommand.SkipText)
  unregCmdFunc(GameCommand.SkipCutscene)
  gEngine.mouseState = MouseState()

method handleInput*(self: EngineState, mouseState: MouseState) =
  gEngine.mouseState = mouseState

method update*(self: EngineState, elapsed: float) =
  gEngine.update(elapsed)
  if not self.noOverride.isNil:
    if not self.noOverride.update(elapsed):
      self.noOverride.remove()
      self.noOverride = nil
  gEngine.render()
import std/[logging, os, strformat, times]
import sqnim
import state
import pausestate
import ../actor
import ../engine
import ../cutscene
import ../eventmanager
import ../gameeventmanager
import ../achievementsmgr
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
import ../../scenegraph/hotspotmarker
import ../../scenegraph/hud
import ../../sys/debugtool
import ../../sys/tools
import ../../sys/app
import ../../sys/input
import ../../sys/colorconsolelogger

type
  EngineState = ref object of State
    packageName, appName: string
    noOverride: NoOverride
    hotspotMarker*: HotspotMarker
    hotspot: bool

var gState: EngineState

proc newEngineState*(packageName, appName: string): EngineState =
  EngineState(packageName: packageName, appName: appName, hotspotMarker: newHotspotMarker())

proc onKey(key: InputKey, scancode: int32, action: InputAction, mods: InputModifierKey) =
  if key == Tab:
    gState.hotspot = action == iaPressed
  if not gEngine.actor.isNil:
    for verb in gEngine.hud.actorSlot(gEngine.actor).verbs:
      if verb.key.len > 0:
        let letter = getText(verb.key)[0]
        if letter.InputKey == key:
          gEngine.hud.verb = verb
          return

method init*(self: EngineState) =
  gState = self
  app.setKeyCallback(onKey)

  # create loggers
  var fmtStr = "$datetime | $levelname | "
  addHandler(newColorConsoleLogger(fmtStr=fmtStr))
  addHandler(newRollingFileLogger("errors.log", levelThreshold=lvlWarn, fmtStr=fmtStr))
  addHandler(newRollingFileLogger("ng.log", fmtStr=fmtStr))

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
  loadAchievements()
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
  gEngine.screen.addChild self.hotspotMarker
  regCmdFunc(GameCommand.ToggleDebug, proc () = gGeneralVisible = not gGeneralVisible)
  regCmdFunc(GameCommand.ShowOptions, proc () = showOptions())
  regCmdFunc(GameCommand.PauseGame, proc () = pushState newPauseState())
  regCmdFunc(GameCommand.SkipText, proc () = stopTalking())
  regCmdFunc(GameCommand.SkipCutscene, proc () = self.skipCutscene())

method deactivate*(self: EngineState) =
  self.hotspotMarker.remove()
  unregCmdFunc(GameCommand.PauseGame)
  unregCmdFunc(GameCommand.ShowOptions)
  unregCmdFunc(GameCommand.SkipText)
  unregCmdFunc(GameCommand.SkipCutscene)
  gEngine.mouseState = MouseState()

method handleInput*(self: EngineState, mouseState: MouseState) =
  gEngine.mouseState = mouseState

method update*(self: EngineState, elapsed: float) =
  self.hotspotMarker.visible = self.hotspot
  gEngine.update(elapsed)
  if not self.noOverride.isNil:
    if not self.noOverride.update(elapsed):
      self.noOverride.remove()
      self.noOverride = nil
  gEngine.render()

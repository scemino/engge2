import std/tables
import glm
import node
import uinode
import textnode
import spritenode
import checkbox
import slider
import switcher
import saveloaddlg
import quitdlg
import sqnim
import ../gfx/color
import ../gfx/graphics
import ../gfx/text
import ../gfx/spritesheet
import ../game/resmanager
import ../game/screen
import ../game/prefs
import ../game/states/state
import ../game/states/dlgstate
import ../game/gameloader
import ../io/textdb
import ../script/squtils
import ../script/vm
import ../sys/app
import ../audio/audio

const
  Options = 99913
  SaveGame = 99911
  LoadGame = 99910
  Video = 99917
  Controls = 99918
  Controller = 99940
  ScrollSyncCursor = 99960
  InvertVerbColors = 99964
  RetroFonts = 99933
  RetroVerbs = 99934
  ClassicSentence = 99935
  Fullscreen = 99927
  ToiletPaperOver = 99965
  AnnoyingInJokes = 99971
  TextAndSpeech = 99919
  TextSpeed = 99941
  DisplayText = 99942
  HearVoice = 99943
  EnglishText = 98001
  FrenchText = 98003
  ItalianText = 98005
  GermanText = 98007
  SpanishText = 98009
  Sound = 99916
  SoundVolume = 99937
  MusicVolume = 99938
  VoiceVolume = 99939
  Help = 99961
  Quit = 99915
  Back = 99904
  varNames = {Fullscreen: "windowFullscreen", ToiletPaperOver: "toilet_paper_over", AnnoyingInJokes: "annoying_injokes", Controller: "controller", ScrollSyncCursor: "controllerScollLockCursor", InvertVerbColors: "invertVerbHighlight", RetroFonts: "retroFonts", RetroVerbs: "retroVerbs", ClassicSentence: "hudSentence", TextSpeed: "sayLineSpeed", DisplayText: "talkiesShowText", HearVoice: "talkiesHearVoice"}.toTable
  varPrefNames = {Fullscreen: prefs.Fullscreen, ToiletPaperOver: prefs.ToiletPaperOver, AnnoyingInJokes: prefs.AnnoyingInJokes, Controller: prefs.Controller, ScrollSyncCursor: prefs.ScrollSyncCursor, InvertVerbColors: prefs.InvertVerbHighlight, RetroFonts: prefs.RetroFonts, RetroVerbs: prefs.RetroVerbs, ClassicSentence: prefs.ClassicSentence, TextSpeed: prefs.SayLineSpeed, DisplayText: prefs.DisplayText, HearVoice: prefs.HearVoice}.toTable
  varPrefDefValues = {Fullscreen: prefs.FullscreenDefValue, ToiletPaperOver: prefs.ToiletPaperOverDefValue, AnnoyingInJokes: prefs.AnnoyingInJokesDefValue, Controller: prefs.ControllerDefValue, ScrollSyncCursor: prefs.ScrollSyncCursorDefValue, InvertVerbColors: prefs.InvertVerbHighlightDefValue, RetroFonts: prefs.RetroFontsDefValue, RetroVerbs: prefs.RetroVerbsDefValue, ClassicSentence: prefs.ClassicSentenceDefValue, DisplayText: prefs.DisplayTextDefValue, HearVoice: prefs.HearVoiceDefValue}.toTable
  varPrefDefFloatValues = {TextSpeed: prefs.SayLineSpeedDefValue}.toTable

type
  OptionsDialogMode* = enum
    FromStartScreen
    FromGame
  OptionsDialog* = ref object of UINode
    mode: OptionsDialogMode
  State = enum
    sOptions
    sVideo
    sControls
    sTextAndSpeech
    sSound

var
  gState: State
  gSelf: OptionsDialog

proc setState(state: State)

proc onQuitClick(node: Node, id: int) =
  case id:
  of Yes:
    quit()
  of No:
    popState(2)
  else:
    discard

proc onSaveLoadBackClick(node: Node, id: int) =
  popState(2)

proc onButtonDown(node: Node, id: int) =
  case id:
  of Quit:
    pushState newDlgState(newQuitDialog(onQuitClick))
  of Back:
    if gState == sOptions:
      popState(1)
    else:
      setState(sOptions)
  of Video:
    setState(sVideo)
  of Controls:
    setState(sControls)
  of TextAndSpeech:
    setState(sTextAndSpeech)
  of Sound:
    setState(sSound)
  of LoadGame:
    pushState newDlgState(newSaveLoadDialog(smLoad, onSaveLoadBackClick))
  of SaveGame:
    pushState newDlgState(newSaveLoadDialog(smSave, onSaveLoadBackClick))
  else:
    discard

proc enabled(id: int): bool =
  id != SaveGame or gAllowSaveGames

proc onButton(src: Node, event: EventKind, pos: Vec2f, tag: pointer) =
  if src.uiNode().active:
    let id = cast[int](tag)
    case event:
    of Enter:
      if enabled(id):
        src.color = Yellow
        playSoundHover()
    of Leave:
      src.color = White
    of Down:
      if enabled(id):
        src.color = White
        onButtonDown(src.getParent, id)
    else:
      discard

proc newHeader(id: int): TextNode =
  let titleTxt = newText(gResMgr.font("HeadingFont"), getText(id), thCenter)
  result = newTextNode(titleTxt)
  result.pos = vec2(ScreenWidth/2f - titleTxt.bounds.x/2f, 680f)
  result.alpha = if enabled(id): 1f else: 0.5f
  result.addButton(onButton, cast[pointer](id))

proc newButton(id: int, y: float, font = "UIFontLarge"): TextNode =
  let titleTxt = newText(gResMgr.font(font), getText(id), thCenter)
  result = newTextNode(titleTxt)
  result.pos = vec2(ScreenWidth/2f - titleTxt.bounds.x/2f, y)
  result.alpha = if enabled(id): 1f else: 0.5f
  result.addButton(onButton, cast[pointer](id))

proc newBackground(): SpriteNode =
  let sheet = gResMgr.spritesheet("SaveLoadSheet")
  result = newSpriteNode(gResMgr.texture(sheet.meta.image), sheet.frame("options_background"))
  result.scale = vec2(4f, 4f)
  result.pos = vec2(ScreenWidth/2f, ScreenHeight/2f)

proc checkbox(self: Node, id: int): Checkbox =
  for node in self.children:
    if node of Checkbox:
      let checkbox = cast[Checkbox](node)
      if checkbox.id == id:
        return checkbox

proc onCheckVar(self: Checkbox, state: bool) =
  let id = cast[int](self.tag)
  setPrefs(varPrefNames[id], state)
  sqCall("setSettingVar", [varNames[id], if state: 1 else: 0])
  self.check(state)
  if id == RetroFonts:
    gResMgr.resetFont("sayline")
  elif id == RetroVerbs and state:
    self.parent.checkbox(RetroFonts).onCheckVar(true)
    self.parent.checkbox(ClassicSentence).onCheckVar(true)
  elif id == Fullscreen:
    app.setFullscreen(state)

proc onSliderVar(self: Slider, value: float32) =
  let id = cast[int](self.tag)
  setPrefs(varPrefNames[id], value)
  sqCall("setSettingVar", [varNames[id], value])

proc newSliderVar*(id: int, y: float): Slider =
  let value = prefs(varPrefNames[id], varPrefDefFloatValues[id])
  newSlider(id, y, onSliderVar, value, cast[pointer](id))

proc newCheckVar*(id: int, y: float, enabled = true): Checkbox =
  let value = prefs(varPrefNames[id], varPrefDefValues[id])
  newCheckbox(id, y, onCheckVar, value, cast[pointer](id), enabled)

proc onSwitch(self: Switcher, value: int) =
  const values = ["en", "fr", "it", "de", "es"]
  setPrefs(Lang, values[value])
  initTextDb()
  sqCall("onLanguageChange")
  discard

proc onSlide(self: Slider, value: float32) =
  case self.id:
  of SoundVolume:
    setPrefs(VolumeSound, value)
    sqCall("soundMixVolume", [value])
  of MusicVolume:
    setPrefs(VolumeMusic, value)
    sqCall("musicMixVolume", [value])
  of VoiceVolume:
    setPrefs(VolumeTalkies, value)
    sqCall("talkieMixVolume", [value])
  else:
    discard

proc update() =
  gSelf.removeAll
  gSelf.addChild newBackground()
  case gState:
  of sOptions:
    gSelf.addChild newHeader(Options)
    gSelf.addChild newButton(SaveGame, 600f)
    gSelf.addChild newButton(LoadGame, 540f)
    gSelf.addChild newButton(Sound, 480f)
    gSelf.addChild newButton(Video, 420f)
    gSelf.addChild newButton(Controls, 360f)
    gSelf.addChild newButton(TextAndSpeech, 300f)
    gSelf.addChild newButton(Help, 240f)
    gSelf.addChild newButton(Quit, 180f)
    gSelf.addChild newButton(Back, 100f, "UIFontMedium")
  of sVideo:
    gSelf.addChild newHeader(Video)
    gSelf.addChild newCheckVar(Fullscreen, 420f)
    gSelf.addChild newCheckVar(ToiletPaperOver, 360f)
    gSelf.addChild newCheckVar(AnnoyingInJokes, 300f)
    gSelf.addChild newButton(Back, 100f, "UIFontMedium")
  of sControls:
    gSelf.addChild newHeader(Controls)
    gSelf.addChild newCheckVar(Controller, 540f, false)
    gSelf.addChild newCheckVar(ScrollSyncCursor, 480f, false)
    gSelf.addChild newCheckVar(InvertVerbColors, 400f)
    gSelf.addChild newCheckVar(RetroFonts, 340f)
    gSelf.addChild newCheckVar(RetroVerbs, 280f)
    gSelf.addChild newCheckVar(ClassicSentence, 220f)
    gSelf.addChild newButton(Back, 100f, "UIFontMedium")
  of sTextAndSpeech:
    gSelf.addChild newHeader(TextAndSpeech)
    gSelf.addChild newSliderVar(TextSpeed, 540f)
    gSelf.addChild newCheckVar(DisplayText, 400f)
    gSelf.addChild newCheckVar(HearVoice, 340f)
    gSelf.addChild newSwitcher(280f, onSwitch, @[EnglishText, FrenchText, ItalianText, GermanText, SpanishText], EnglishText)
    gSelf.addChild newButton(Back, 100f, "UIFontMedium")
  of sSound:
    gSelf.addChild newHeader(Sound)
    var vol: float32
    sqCallFunc(vol, "soundMixVolume", [])
    gSelf.addChild newSlider(SoundVolume, 540f, onSlide, vol)
    sqCallFunc(vol, "musicMixVolume", [])
    gSelf.addChild newSlider(MusicVolume, 440f, onSlide, vol)
    sqCallFunc(vol, "talkieMixVolume", [])
    gSelf.addChild newSlider(VoiceVolume, 340f, onSlide, vol)
    gSelf.addChild newButton(Back, 100f, "UIFontMedium")

proc setState(state: State) =
  gState = state
  update()

proc newOptionsDialog*(mode: OptionsDialogMode): OptionsDialog =
  gSelf = OptionsDialog(mode: mode)
  result = gSelf
  result.init()
  update()

method drawCore(self: OptionsDialog, transf: Mat4f) =
  gfxDrawQuad(vec2(0f, 0f), vec2f(ScreenWidth, ScreenHeight), rgbaf(Black, 0.5f), transf)
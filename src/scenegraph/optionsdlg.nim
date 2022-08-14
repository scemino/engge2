import glm
import node
import textnode
import spritenode
import checkbox
import slider
import switcher
import sqnim
import ../gfx/color
import ../gfx/text
import ../gfx/spritesheet
import ../game/resmanager
import ../game/screen
import ../io/textdb
import ../script/squtils
import ../script/vm
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

type
  OptionsDialog* = ref object of Node
  State = enum
    sOptions
    sVideo
    sControls
    sTextAndSpeech
    sSound

var
  gDisabled: seq[int]
  gState: State
  gSelf: OptionsDialog

proc setState(state: State)

proc onButtonDown(node: Node, id: int) =
  case id:
  of Quit:
    quit()
  of Back:
    setState(sOptions)
  of Video:
    setState(sVideo)
  of Controls:
    setState(sControls)
  of TextAndSpeech:
    setState(sTextAndSpeech)
  of Sound:
    setState(sSound)
  else:
    discard

proc onButton(src: Node, event: EventKind, pos: Vec2f, tag: pointer) =
  let id = cast[int](tag)
  case event:
  of Enter:
    if not gDisabled.contains(id):
      src.color = Yellow
  of Leave:
    src.color = White
  of Down:
    onButtonDown(src.getParent, id)
  else:
    discard

proc newHeader(id: int): TextNode =
  let titleTxt = newText(gResMgr.font("HeadingFont"), getText(id), thCenter)
  result = newTextNode(titleTxt)
  result.pos = vec2(ScreenWidth/2f - titleTxt.bounds.x/2f, 680f)
  result.alpha = if gDisabled.contains(id): 0.5f else: 1f
  result.addButton(onButton, cast[pointer](id))

proc newButton(id: int, y: float, font = "UIFontLarge"): TextNode =
  let titleTxt = newText(gResMgr.font(font), getText(id), thCenter)
  result = newTextNode(titleTxt)
  result.pos = vec2(ScreenWidth/2f - titleTxt.bounds.x/2f, y)
  result.alpha = if gDisabled.contains(id): 0.5f else: 1f
  result.addButton(onButton, cast[pointer](id))

proc newBackground(): SpriteNode =
  let sheet = gResMgr.spritesheet("SaveLoadSheet")
  result = newSpriteNode(gResMgr.texture(sheet.meta.image), sheet.frame("options_background"))
  result.scale = vec2(4f, 4f)
  result.pos = vec2(ScreenWidth/2f, ScreenHeight/2f)

proc onCheckVar(self: Checkbox, state: bool) =
  let name = cast[string](self.tag)
  sqCall("setSettingVar", [name, if state: 1 else: 0])
  self.check(state)

proc onSliderVar(self: Slider, value: float32) =
  let name = cast[string](self.tag)
  sqCall("setSettingVar", [name, value])

proc newSliderVar*(id: int, y: float, name: string): Slider =
  var value: float32
  sqCallFunc(value, "getSettingVar", [name])
  newSlider(id, y, onSliderVar, value)

proc newCheckVar*(id: int, y: float, name: string): Checkbox =
  var value: bool
  sqCallFunc(value, "getSettingVar", [name])
  newCheckbox(id, y, onCheckVar, value)

proc onSwitch(self: Switcher, value: int) =
  discard

proc onSlide(self: Slider, value: float32) =
  case self.id:
  of SoundVolume:
    sqCall("soundMixVolume", [value])
  of MusicVolume:
    sqCall("musicMixVolume", [value])
  of VoiceVolume:
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
    gSelf.addChild newCheckVar(Fullscreen, 420f, "windowFullscreen")
    gSelf.addChild newCheckVar(ToiletPaperOver, 360f, "toilet_paper_over")
    gSelf.addChild newCheckVar(AnnoyingInJokes, 300f, "annoying_injokes")
    gSelf.addChild newButton(Back, 100f, "UIFontMedium")
  of sControls:
    gSelf.addChild newHeader(Controls)
    gSelf.addChild newCheckVar(Controller, 540f, "controller")
    gSelf.addChild newCheckVar(ScrollSyncCursor, 480f, "controllerScollLockCursor")
    gSelf.addChild newCheckVar(InvertVerbColors, 400f, "invertVerbHighlight")
    gSelf.addChild newCheckVar(RetroFonts, 340f, "retroFonts")
    gSelf.addChild newCheckVar(RetroVerbs, 280f, "retroVerbs")
    gSelf.addChild newCheckVar(ClassicSentence, 220f, "hudSentence")
    gSelf.addChild newButton(Back, 100f, "UIFontMedium")
  of sTextAndSpeech:
    gSelf.addChild newHeader(TextAndSpeech)
    gSelf.addChild newSliderVar(TextSpeed, 540f, "sayLineSpeed")
    gSelf.addChild newCheckVar(DisplayText, 400f, "talkiesShowText")
    gSelf.addChild newCheckVar(HearVoice, 340f, "talkiesHearVoice")
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

proc newOptionsDialog*(): OptionsDialog =
  gSelf = OptionsDialog()
  result = gSelf
  result.init()

  gDisabled.add SaveGame
  update()

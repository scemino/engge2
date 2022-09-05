import std/strformat
import std/os
import std/times
import std/json
import glm
import node
import textnode
import spritenode
import nimyggpack
import ../gfx/color
import ../gfx/graphics
import ../gfx/text
import ../gfx/image
import ../gfx/recti
import ../gfx/texture
import ../gfx/spritesheet
import ../game/resmanager
import ../game/screen
import ../game/gameloader
import ../game/states/state
import ../io/textdb
import ../util/strutils
import ../util/time

const
  LoadGame = 99910
  SaveGame = 99911
  Back = 99904

type
  ClickCallback* = proc(node: Node, id: int)
  SaveLoadDialogMode* = enum
    smLoad
    smSave
  SaveLoadDialog* = ref object of Node
    mode: SaveLoadDialogMode
    savegames: array[9, Savegame]
    clickCbk: ClickCallback

proc newHeader(id: int): TextNode =
  let titleTxt = newText(gResMgr.font("HeadingFont"), getText(id), thCenter)
  result = newTextNode(titleTxt)
  result.pos = vec2(ScreenWidth/2f - titleTxt.bounds.x/2f, 690f)

proc onButton(src: Node, event: EventKind, pos: Vec2f, tag: pointer) =
  case event:
  of Enter:
    src.color = Yellow
  of Leave:
    src.color = White
  of Down:
    let dlg = cast[SaveLoadDialog](src.getParent())
    dlg.clickCbk(dlg, Back)
  else:
    discard

proc newButton(id: int, y: float, font = "UIFontLarge"): TextNode =
  let titleTxt = newText(gResMgr.font(font), getText(id), thCenter)
  result = newTextNode(titleTxt)
  result.pos = vec2(ScreenWidth/2f - titleTxt.bounds.x/2f, y)
  result.addButton(onButton, cast[pointer](result))

proc newBackground(): SpriteNode =
  let sheet = gResMgr.spritesheet("SaveLoadSheet")
  result = newSpriteNode(gResMgr.texture(sheet.meta.image), sheet.frame("saveload"))
  result.scale = vec2(4f, 4f)
  result.pos = vec2(ScreenWidth/2f, ScreenHeight/2f)

proc loadTexture(file: string): Texture =
  let f = open(file, fmRead)
  let size = f.getFileSize
  var buff = newSeq[byte](size)
  discard f.readBytes(buff, 0, size)
  f.close
  newTexture(newImage(buff))

proc fmtTime(time: Time): string =
  # time format: "%b %d at %H:%M"
  fmtTimeLikeC(time, getText(99944))

proc fmtGameTime(timeInSec: float): string =
  var buffer: array[120, char]
  var buf = cast[cstring](buffer[0].addr)
  var min = timeInSec.int div 60
  if min < 2:
    # "%d minute"
    discard snprintf(buf, 120, getText(99945).cstring, min)
  elif min < 60:
    # "%d minutes"
    discard snprintf(buf, 120, getText(99946).cstring, min)
  else:
    var format: int
    var hour = min div 60
    min = min mod 60
    if hour < 2 and min < 2:
      # "%d hour %d minute"
      format = 99947
    elif hour < 2 and min >= 2:
      # "%d hour %d minutes"
      format = 99948;
    elif hour >= 2 and min < 2:
      # "%d hours %d minute"
      format = 99949;
    else:
      # "%d hours %d minutes";
      format = 99950
    discard snprintf(buf, 120, getText(format).cstring, hour, min)
  $buf

proc onGameButton(src: Node, event: EventKind, pos: Vec2f, tag: pointer) =
  let data = cast[JsonNode](tag)
  case event:
  of Down:
    popState(stateCount() - 1)
    let dlg = cast[SaveLoadDialog](src.getParent())
    if dlg.mode == smLoad:
      loadGame(data)
    else:
      saveGame(data)
  else:
    discard

proc newSaveLoadDialog*(mode: SaveLoadDialogMode, clickCbk: ClickCallback): SaveLoadDialog =
  result = SaveLoadDialog(mode: mode, clickCbk: clickCbk)
  result.addChild newBackground()
  result.addChild newHeader(if mode == smLoad: LoadGame else: SaveGame)

  let sheet = gResMgr.spritesheet("SaveLoadSheet")
  let slotFrame = sheet.frame("saveload_slot_frame")
  let scale = vec2(4f*slotFrame.frame.w.float32/320f, 4f*slotFrame.frame.h.float32/180f)
  let fontSmallBold = gResMgr.font("UIFontSmall")
  
  for i in 0..<9:
    let path = fmt"Savegame{i+1}.png"
    let savePath = changeFileExt(path, "save")
    if fileExists(path) and fileExists(savePath):
      # load savegame data
      let savegame = loadSaveGame(savePath)
      result.savegames[i] = savegame
      let easyMode = savegame.data["easy_mode"].getInt() != 0
      let gameTime = savegame.data["gameTime"].getFloat()
      var saveTimeText = if i==0: getText(99901) else: fmtTime(savegame.time)
      if easyMode:
        saveTimeText &= ' ' & getText(99955)

      # thumbnail
      let sn = newSpriteNode(loadTexture(path))
      sn.scale = scale
      sn.setAnchorNorm(vec2(0.5f, 0.5f))
      sn.pos = vec2f(scale.x * (1f + (i mod 3).float32) * (sn.size.x + 4f), (scale.y * ((8-i) div 3).float32 * (sn.size.y + 4f)))
      sn.addButton(onGameButton, cast[pointer](result.savegames[i].data))
      result.addChild sn

      # game time text
      let gtt = newTextNode(newText(fontSmallBold, fmtGameTime(gameTime), thCenter))
      gtt.setAnchorNorm(vec2(0.5f, 0.5f))
      gtt.pos = vec2(310f + 320f*(i mod 3).float32, 240f + 180*((8-i) div 3).float32)
      result.addChild gtt

      # save time text
      let stt = newTextNode(newText(fontSmallBold, saveTimeText, thCenter))
      stt.setAnchorNorm(vec2(0.5f, 0.5f))
      stt.pos = vec2(310f + 320f*(i mod 3).float32, 110f + 180*((8-i) div 3).float32)
      result.addChild stt

    # frame
    let sn = newSpriteNode(gResMgr.texture(sheet.meta.image), slotFrame)
    sn.scale = vec2(4f, 4f)
    sn.setAnchorNorm(vec2(0.5f, 0.5f))
    sn.pos = vec2f((1f + (i mod 3).float32) * 4f * (sn.size.x + 1f), 4f * (i div 3).float32 * (sn.size.y + 1f))
    result.addChild sn

  result.addChild newButton(Back, 80f, "UIFontMedium")

  result.init()

method drawCore(self: SaveLoadDialog, transf: Mat4f) =
  gfxDrawQuad(vec2(0f, 0f), vec2f(ScreenWidth, ScreenHeight), rgbaf(Black, 0.5f), transf)
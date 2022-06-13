import glm
import sqnim
import ../debugtool
import ../../game/engine
import ../../game/room
import ../../game/shaders
import ../../libs/imgui
import ../../sys/app
import ../../script/vm

const
  RoomEffects = "None\0Sepia\0EGA\0VHS\0Ghost\0Black & White\0"

type 
  GeneralTool = ref object of DebugTool

var 
  gGeneralVisible = true

proc newGeneralTool*(): GeneralTool =
  result = GeneralTool()

proc getRoom(data: pointer, idx: int32, out_text: ptr constChar): bool {.cdecl.} =
  if idx in 0..<gEngine.rooms.len:
    out_text[] = cast[constChar](gEngine.rooms[idx].name[0].addr)
    result = true
  else:
    result = false

method render*(self: GeneralTool) =
  if gEngine.isNil or not gGeneralVisible:
    return

  igBegin("General".cstring, addr gGeneralVisible)

  let inCutscene = not gEngine.cutscene.isNil
  let scrPos = gEngine.winToScreen(mousePos())
  let roomPos = gEngine.room.screenToRoom(scrPos)
  igText("In cutscene: %s", if inCutscene: "yes".cstring else: "no".cstring)
  igText("Pos (screen): (%.0f, %0.f)", scrPos.x, scrPos.y)
  igText("Pos (room): (%.0f, %0.f)", roomPos.x, roomPos.y)
  igText("VM stack top: %d", sq_gettop(gVm.v))
  igSeparator()

  let room = gEngine.room
  var index = gEngine.rooms.find(room).int32
  if igCombo("Room", index.addr, getRoom, nil, gEngine.rooms.len.int32, -1'i32):
    gEngine.setRoom(gEngine.rooms[index])
  
  if not room.isNil:
    igText("Sheet: %s", room.sheet[0].addr)
    igText("Size: %d x %d", room.roomSize.x, room.roomSize.y)
    igText("Fullscreen: %d", room.fullScreen)
    igText("Height: %d", room.height)
    igColorEdit4("Overlay", room.overlay.arr)

    var effect = room.effect.int32
    if igCombo("Shader", effect.addr, RoomEffects):
      room.effect = effect.RoomEffect
    igDragFloat("iFade", gShaderParams.iFade.addr, 0.01f, 0f, 1f);
    igDragFloat("wobbleIntensity", gShaderParams.wobbleIntensity.addr, 0.01f, 0f, 1f)
    igDragFloat3("shadows", gShaderParams.shadows.arr, 0.01f, -1f, 1f)
    igDragFloat3("midtones", gShaderParams.midtones.arr, 0.01f, -1f, 1f)
    igDragFloat3("highlights", gShaderParams.highlights.arr, 0.01f, -1f, 1f)


  # if I remove this it does not compile, why ???
  if igBeginTable("???", 1, (Borders.int or SizingFixedFit.int or Resizable.int or RowBg.int).ImGuiTableFlags):
    igEndTable()

  igEnd()

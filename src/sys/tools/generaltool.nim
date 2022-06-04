import glm
import ../debugtool
import ../../game/engine
import ../../game/room
import ../../libs/imgui
import ../../sys/app


type 
  GeneralTool = ref object of DebugTool

var 
  gGeneralVisible = true
  gRoomIndex = -1'i32

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
  igSeparator()

  if igCombo("Room", gRoomIndex.addr, getRoom, nil, gEngine.rooms.len.int32, -1'i32):
    gEngine.setRoom(gEngine.rooms[gRoomIndex])
  
  if gRoomIndex >= 0:
    let room = gEngine.rooms[gRoomIndex]
    igText("Sheet: %s", room.sheet[0].addr)
    igText("Size: %d x %d", room.roomSize.x, room.roomSize.y)
    igText("Fullscreen: %d", room.fullScreen)
    igText("Height: %d", room.height)
    igColorEdit4("Overlay", room.overlay.arr)

  # if I remove this it does not compile, why ???
  if igBeginTable("???", 1, (Borders.int or SizingFixedFit.int or Resizable.int or RowBg.int).ImGuiTableFlags):
    igEndTable()

  igEnd()

import std/strformat
import std/tables
import ../debugtool
import ../../game/resmanager
import ../../gfx/texture
import ../../libs/imgui

type TextureTool = ref object of DebugTool

proc newTextureTool*(): TextureTool =
  result = TextureTool()

var gTexturesVisible = true

proc convertSize(size: int): string =
  const suffix = ["B", "KB", "MB", "GB", "TB"]
  var s = size
  var dblBytes = size.float
  var i = 0
  if s > 1024:
    while s div 1024 > 0 and i < suffix.len:
      dblBytes = s.float / 1024.0
      s = s div 1024
      i += 1
  return fmt"{dblBytes:.2f} {suffix[i]}"

method render*(self: TextureTool) =
  if gResMgr.isNil or not gTexturesVisible:
    return

  var total = 0
  for (k,tex) in gResMgr.textures.pairs:
    total += tex.width * tex.height * 4

  igBegin("Textures".cstring, addr gTexturesVisible)
  igText("# textures: %d", gResMgr.textures.len)
  igText("Total memory: %s", convertSize(total))
  igSeparator()
    
  if igBeginTable("Textures", 3, (Borders.int or SizingFixedFit.int or Resizable.int or RowBg.int).ImGuiTableFlags):
    igTableSetupColumn("Name")
    igTableSetupColumn("Resolution")
    igTableSetupColumn("Size")
    igTableHeadersRow()

    for (k, tex) in gResMgr.textures.pairs:
      igTableNextRow()
      igTableNextColumn()
      igText("%s", k.cstring)
      igTableNextColumn()
      igText("%d x %d", tex.width, tex.height)
      igTableNextColumn()
      igText("%s", convertSize(tex.width * tex.height * 4).cstring)
    
    igEndTable()

  igEnd()

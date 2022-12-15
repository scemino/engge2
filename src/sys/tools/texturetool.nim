import std/strformat
import std/tables
import ../debugtool
import ../../game/resmanager
import ../../gfx/texture
import nglib

type TextureTool = ref object of DebugTool
  visible*: bool

proc newTextureTool*(): TextureTool =
  result = TextureTool()

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
  if gResMgr.isNil or not self.visible:
    return

  var total = 0
  for (k,tex) in gResMgr.textures.pairs:
    total += tex.width * tex.height * 4

  igSetNextWindowSize(ImVec2(x: 520, y: 600), ImGuiCond.FirstUseEver)
  igBegin("Textures".cstring, addr self.visible)
  igText("# textures: %d", gResMgr.textures.len)
  igText("Total memory: %s", convertSize(total).cstring)
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

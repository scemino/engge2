import sqnim
import std/logging
import std/strformat
import ../../libs/imgui
import ../../game/engine
import ../../game/thread
import ../debugtool

type ThreadTool = ref object of DebugTool
  visible*: bool

proc newThreadTool*(): ThreadTool =
  result = ThreadTool()

proc getState(thread: ThreadBase): string =
  if thread.isSuspended():
    return "suspended"
  if thread.isDead():
    return "stopped"
  return "playing"

proc showControls(thread: ThreadBase) =
  if thread.isSuspended():
    if igSmallButton("resume"):
      thread.resume()
    igSameLine()
  else:
    if igSmallButton("pause") and thread.pauseable:
      thread.suspend()
    igSameLine()
  if igSmallButton("stop"):
    thread.stop()

method render*(self: ThreadTool) =
  if gEngine.isNil or not self.visible:
    return

  let threads = gEngine.threads
  igSetNextWindowSize(ImVec2(x: 520, y: 600), ImGuiCond.FirstUseEver)
  igBegin("Threads", addr self.visible)
  igText("# threads: %lu", threads.len)
  igSeparator()

  if igBeginTable("Threads", 8, (Borders.int or SizingFixedFit.int or Resizable.int or RowBg.int).ImGuiTableFlags):
    igTableSetupColumn("")
    igTableSetupColumn("Id")
    igTableSetupColumn("Name")
    igTableSetupColumn("Type")
    igTableSetupColumn("State")
    igTableSetupColumn("Func")
    igTableSetupColumn("Src")
    igTableSetupColumn("Line")
    igTableHeadersRow()

    if not gEngine.cutscene.isNil:
      let thread = gEngine.cutscene
      let name = thread.getName()
      let id = thread.getId()
      let kind = if thread.global: "global" else: "local"
      let state = thread.getState()
      var infos: SQStackInfos
      discard sq_stackinfos(thread.getThread(), 0, infos)

      igTableNextRow()
      igTableNextColumn()
      showControls(thread)
      igTableNextColumn()
      igText("%5d", id)
      igTableNextColumn()
      igText("%-56s", name.cstring)
      igTableNextColumn()
      igText("%-6s", kind.cstring)
      igTableNextColumn()
      igText("%-9s", state.cstring)
      igTableNextColumn()
      igText("%-9s", infos.funcname)
      igTableNextColumn()
      igText("%-9s", infos.source)
      igTableNextColumn()
      igText("%5d", infos.line)

    for thread in threads:
      let name = thread.getName()
      let id = thread.getId()
      let kind = if thread.global: "global" else: "local"
      let state = thread.getState()
      var infos: SQStackInfos
      discard sq_stackinfos(thread.getThread(), 0, infos)

      igTableNextRow()
      igTableNextColumn()
      showControls(thread)
      igTableNextColumn()
      igText("%5d", id)
      igTableNextColumn()
      igText("%-56s", name.cstring)
      igTableNextColumn()
      igText("%-6s", kind.cstring)
      igTableNextColumn()
      igText("%-9s", state.cstring)
      igTableNextColumn()
      igText("%-9s", infos.funcname)
      igTableNextColumn()
      igText("%-9s", infos.source)
      igTableNextColumn()
      igText("%5d", infos.line)
    igEndTable()
  igEnd()

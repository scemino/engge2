import ../../libs/imgui
import ../../game/engine
import ../../game/thread
import ../debugtool

type ThreadTool = ref object of DebugTool

proc newThreadTool*(): ThreadTool =
  result = ThreadTool()

var gThreadsVisible = true

proc getState(thread: Thread): string =
  if thread.isSuspended():
    return "suspended"
  if thread.isDead():
    return "stopped"
  return "playing"

proc showControls(thread: Thread) =
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
  if gEngine.isNil or not gThreadsVisible:
    return

  let threads = gEngine.threads
  igBegin("Threads", addr gThreadsVisible)
  igText("# threads: %lu", threads.len)
  igSeparator()

  if igBeginTable("Threads", 5, (Borders.int or SizingFixedFit.int or Resizable.int or RowBg.int).ImGuiTableFlags):
    igTableSetupColumn("")
    igTableSetupColumn("Id")
    igTableSetupColumn("Name")
    igTableSetupColumn("Type")
    igTableSetupColumn("State")
    igTableHeadersRow()

    for thread in threads:
      let name = thread.name
      let id = thread.id
      let kind = if thread.global: "global" else: "local"
      let state = thread.getState()

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
    igEndTable()
  igEnd()

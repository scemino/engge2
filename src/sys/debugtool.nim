type
  DebugTool* = ref object of RootObj

var 
  gDebugTools: seq[DebugTool]

proc addDebugTool*(tool: DebugTool) =
  gDebugTools.add tool

iterator debugTools*(): DebugTool =
  for tool in gDebugTools:
    yield tool

method render*(self: DebugTool) {.base.} =
  discard
type
  DebugTool* = ref object of RootObj

var 
  gDebugTools: seq[DebugTool]
  gGeneralVisible*: bool

proc addDebugTool*(tool: DebugTool) =
  gDebugTools.add tool

iterator debugTools*(): DebugTool =
  for tool in gDebugTools:
    yield tool

method render*(self: DebugTool) {.base.} =
  discard
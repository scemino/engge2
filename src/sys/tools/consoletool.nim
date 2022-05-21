import ../debugtool
import std/logging
import console

type 
  ConsoleTool = ref object of DebugTool
    console*: Console
    visible: bool

  ConsoleToolLogger = ref object of Logger
    tool: ConsoleTool

proc newConsoleTool*(): ConsoleTool =
  result = ConsoleTool(console: newConsole(), visible: true)

method render*(self: ConsoleTool) =
  self.console.draw(self.visible.addr)

proc newConsoleToolLogger*(tool: ConsoleTool): ConsoleToolLogger =
  ## Creates a logger that logs to a ConsoleTool.
  ConsoleToolLogger(tool: tool)

method log*(logger: ConsoleToolLogger, level: Level, args: varargs[string, `$`]) =
  let ln = substituteLog(logger.fmtStr, level, args)
  let msg = if level >= lvlWarn: "[error]" & ln else: ln
  logger.tool.console.addLog(msg)
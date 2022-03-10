import std/logging
import ../ui/console

type
  ImGuiLogger = ref object of Logger
    console: Console

proc newImGuiLogger*(console: Console): ImGuiLogger =
  new(result)
  result.console = console

method log(self: ImGuiLogger; level: Level; args: varargs[string, `$`]) =
  self.console.addLog(substituteLog("$levelname ", level, args))
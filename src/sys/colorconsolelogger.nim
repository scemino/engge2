import std/strutils, std/terminal
import std/logging as logging
export strutils.format

proc getColor(lvl: Level): ForegroundColor = 
  ## Gets color for the specified logging level
  case lvl
  of lvlDebug, lvlAll, lvlNone, lvlInfo: fgWhite
  of lvlNotice: fgCyan
  of lvlWarn: fgYellow
  of lvlError, lvlFatal: fgRed

type 
  ColorConsoleLogger* = ref object of logging.Logger
    ## A logger that writes log messages to the console with colors.
    ##
    ## Create a new ``ColorConsoleLogger`` with the `newColorConsoleLogger proc
    ## <#newColorConsoleLogger>`_.
    ##
    ## See also:
    ## * `FileLogger<#FileLogger>`_
    ## * `RollingFileLogger<#RollingFileLogger>`_
    useStderr*: bool ## If true, writes to stderr; otherwise, writes to stdout

proc newColorConsoleLogger*(levelThreshold = lvlAll, fmtStr = logging.defaultFmtStr, useStderr = false): ColorConsoleLogger =
  result = ColorConsoleLogger(useStderr: useStderr, fmtStr: fmtStr, levelThreshold: levelThreshold)

method log*(logger: ColorConsoleLogger, level: Level, args: varargs[string, `$`]) =
  ## Logs message with specified log level to the stdout
  # Only print messages with specified log level or higher
  if level >= logger.levelThreshold:
    let ln = substituteLog(logger.fmtStr, level, args)
    setForegroundColor(stdout, getColor(level))
    var handle = stdout
    if logger.useStderr:
      handle = stderr
    handle.writeLine(ln)
    resetAttributes()
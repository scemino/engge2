import std/logging
import std/tables
import prefs
import ../sys/input

type
  GameCommand* = enum
    SkipText
    SkipCutscene
    PauseGame
    SelectActor1
    SelectActor2
    SelectActor3
    SelectActor4
    SelectActor5
    SelectActor6
    SelectChoice1
    SelectChoice2
    SelectChoice3
    SelectChoice4
    SelectChoice5
    SelectChoice6
    SelectPreviousActor
    SelectNextActor
    ShowOptions
    ToggleHud
    ToggleDebug
    Screenshot
  Input* = object
    modf*: InputModifierKey
    key*: InputKey
  CommandHandler* = proc()

var
  gMappings = {
    Input(key: InputKey.Space): @[PauseGame],
    Input(key: InputKey.Escape): @[SkipCutscene],
    Input(modf: Control, key: InputKey.O): @[ShowOptions],
    Input(modf: Control, key: InputKey.U): @[ToggleHud],
    Input(modf: Control, key: InputKey.D): @[ToggleDebug],
    Input(modf: Control, key: InputKey.S): @[Screenshot],
    }.toTable
  prefsMappings = [
    (KeySkipText, KeySkipTextDefValue, SkipText), 
    (KeySelect1, KeySelect1DefValue, SelectActor1),
    (KeySelect2, KeySelect2DefValue, SelectActor2),
    (KeySelect3, KeySelect3DefValue, SelectActor3),
    (KeySelect4, KeySelect4DefValue, SelectActor4),
    (KeySelect5, KeySelect5DefValue, SelectActor5),
    (KeySelect6, KeySelect6DefValue, SelectActor6),
    (KeySelectPrev, KeySelectPrevDefValue, SelectPreviousActor),
    (KeySelectNext, KeySelectNextDefValue, SelectNextActor),
    (KeyChoice1, KeyChoice1DefValue, SelectChoice1),
    (KeyChoice2, KeyChoice2DefValue, SelectChoice2),
    (KeyChoice3, KeyChoice3DefValue, SelectChoice3),
    (KeyChoice4, KeyChoice4DefValue, SelectChoice4),
    (KeyChoice5, KeyChoice5DefValue, SelectChoice5),
    (KeyChoice6, KeyChoice6DefValue, SelectChoice6),
  ]
  gHandlers: Table[GameCommand, proc()]

proc toKey(keyText: string): InputKey =
  if keyText.len == 1:
    result = keyText[0].InputKey

proc toKey(name: string, value: string): InputKey =
  toKey(prefs(name, value))

proc regCmds*() =
  for mapping in prefsMappings:
    let input = Input(key: toKey(mapping[0], mapping[1]))
    if gMappings.hasKey input:
      gMappings[input].add mapping[2]
    else:
      gMappings[input] = @[mapping[2]]

proc regCmdFunc*(cmd: GameCommand, h: CommandHandler) =
  gHandlers[cmd] = h

proc unregCmdFunc*(cmd: GameCommand) =
  gHandlers.del cmd

proc execCmd*(cmd: GameCommand) =
  if gHandlers.hasKey cmd:
    info "exec cmd handler: " & $cmd
    gHandlers[cmd]()

proc execCmd*(input: Input) =
  info "exec cmd: " & $input
  if gMappings.hasKey input:
    info "exec cmd: " & $input & ": " & $gMappings[input]
    for cmd in gMappings[input]:
      execCmd(cmd)
import std/logging
import std/strformat
import engine
import eventmanager
import ../util/utils
import ../audio/audio
import ../script/vm
import ../script/squtils

type GameEventManager = ref object of EventManager

proc newGameEventManager*(): GameEventManager =
  new(result)

method trig(self: GameEventManager, name: string) =
  var id = 0
  getf(name, id)
  var sound = soundDef(id)
  if sound.isNil:
    warn fmt"Cannot trig sound '{name}', sound not found (id={id})"
  else:
    discard gEngine.audio.play(sound, scSound)
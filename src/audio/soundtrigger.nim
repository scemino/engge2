import std/random
import audio
import ../game/trigger
import ../game/engine

type SoundTrigger = ref object of Trigger
  sounds: seq[SoundDefinition]

proc newSoundTrigger*(sounds: seq[SoundDefinition]): SoundTrigger =
  SoundTrigger(sounds: sounds)

method trig(self: SoundTrigger) =
  var i = gEngine.rand.rand(0..<self.sounds.len)
  discard gEngine.audio.play(self.sounds[i], Sound)

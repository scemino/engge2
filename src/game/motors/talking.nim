import std/tables
import std/logging
import std/strformat
import motor
import ../../scenegraph/node
import ../../game/room
import ../../io/lip
import ../../audio/audio
import ../../game/engine

const letterToIndex = {'A': 1, 'B': 2, 'C': 3, 'D': 4, 'E': 5, 'F': 6, 'G': 1 ,'H': 4, 'X': 1}.toTable

type Talking = ref object of Motor
  obj: Object
  node: Node
  lip: Lip
  elapsed: float
  soundId: SoundId

proc newTalking*(obj: Object, lip: Lip, soundId: SoundId): Talking =
  ## Creates a talking animation for a specified object.
  new(result)
  result.obj = obj
  result.lip = lip
  result.node = obj.sayNode
  result.soundId = soundId
  result.enabled = true

method update(self: Talking, el: float) =
  if gEngine.audio.playing(self.soundId):
    var letter = self.lip.letter(self.elapsed)
    self.elapsed += el
    debug fmt"talking update {self.elapsed} {letter}"
    self.obj.setHeadIndex(letterToIndex[letter])
  else:
    self.obj.setHeadIndex(1)
    self.node.remove()
    self.enabled = false
  
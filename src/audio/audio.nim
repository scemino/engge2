import std/logging
import std/strformat
import std/streams
import std/tables
import sdl2
import sdl2/mixer
import ../game/ids
import ../io/ggpackmanager

type
  AudioStatus* = enum
    Stopped,
    Paused,
    Playing
  VolumeKind* = enum
    vkMaster,
    vkMusic,
    vkSound,
    vkTalk
  AudioChannel* = ref object of RootObj
    id*: cint
    numLoops*: int
    vol*: float
    panning: float
    buffer*: SoundBuffer
  SoundBuffer = ref object of RootObj
    chunk: ptr Chunk
  SoundCategory* = enum
    Music,
    Sound,
    Talk
  SoundDefinition* = ref object of RootObj
    id*: int            # identifier for this sound
    name*: string        # name of the sound to load
    buffer: SoundBuffer # buffer containing the sound data
    loaded: bool        # indicates whether or not the sound buffer has been loaded
  SoundId* = ref object of RootObj
    id*: int
    objId*: int
    sndDef*: SoundDefinition
    cat*: SoundCategory
    chan*: AudioChannel
    pan*: float32
  VolFunc = proc(id: SoundId): float32
  AudioSystem* = ref object of RootObj
    chans*: array[32, AudioChannel]
    soundDefs*: seq[SoundDefinition]
    sounds*: array[32, SoundId]
    volumes: Table[VolumeKind, float]
    volFunc: VolFunc
    soundHover*: SoundDefinition

var gAudio*: AudioSystem

proc checkError() =
  let err = sdl2.getError()
  if not err.isNil and err.len > 0:
    error "Audio error: " & $err
  sdl2.clearError()

# SoundBuffer
proc newSoundBuffer*(): SoundBuffer =
  new(result)

proc free(self: SoundBuffer) =
  if not self.chunk.isNil:
    mixer.freeChunk(self.chunk)
    self.chunk = nil

proc destroy*(self: SoundBuffer) =
  self.free()

proc loadMem*(self: SoundBuffer, data: pointer, sizeInBytes: cint) =
  self.chunk = mixer.loadWAV_RW(rwFromConstMem(data, sizeInBytes), 1)
  checkError()

proc load*(self: SoundBuffer, path: string) =
  self.chunk = mixer.loadWAV(path.cstring)
  checkError()

# SoundDefinition
proc newSoundDefinition*(name: string): SoundDefinition =
  result = SoundDefinition(id: newSoundDefId(), name: name, buffer: newSoundBuffer())

proc load*(self: SoundDefinition) =
  if not self.loaded:
    var data = gGGPackMgr.loadStream(self.name).readAll
    self.buffer.loadMem(data[0].addr, data.len.cint)

# AudioChannel
proc newAudioChannel(channel: Natural): AudioChannel =
  AudioChannel(id: channel.cint, vol: 1.0f)

proc status*(self: AudioChannel): AudioStatus =
  if mixer.paused(self.id) == 1:
    checkError()
    Paused
  elif mixer.playing(self.id) == 1:
    checkError()
    Playing
  else:
    Stopped

proc `volume=`*(self: AudioChannel, volume: float) =
  self.vol = volume
  var vol = clamp((volume * 128).int, 0, 128).cint
  discard mixer.volume(self.id, vol)

proc play*(self: AudioChannel; loopTimes = 0; fadeInTimeMs = 0.0) =
  if not self.buffer.isNil:
    case self.status():
    of Paused:
      info "resume"
      mixer.resume(self.id)
      checkError()
    of Stopped:
      self.numLoops = loopTimes
      if fadeInTimeMs == 0:
        # info "playChannel"
        discard mixer.playChannel(self.id, self.buffer.chunk, loopTimes.cint)
        checkError()
      else:
        # info "fadeInChannel"
        discard mixer.fadeInChannel(self.id, self.buffer.chunk, loopTimes.cint, fadeInTimeMs.cint)
        checkError()
    of Playing:
      return

proc stop*(self: AudioChannel, fadeOutTimeSec = 0.0) =
  if fadeOutTimeSec <= 0.001:
    info fmt"halt channel {self.id}"
    discard mixer.haltChannel(self.id)
    checkError()
  else:
    info fmt"fadeout channel {self.id} for {fadeOutTimeSec} s"
    discard mixer.fadeOutChannel(self.id, (fadeOutTimeSec * 1000).cint)
    checkError()

proc pause*(self: AudioChannel) =
  mixer.pause(self.id)

proc resume*(self: AudioChannel) =
  mixer.resume(self.id)

proc setPan*(self: AudioChannel, panNorm: float32) =
  let pan = clamp(panNorm * 128f, -127f, 128f)
  let left = (128f - pan).byte
  discard mixer.setPanning(self.id, left, 255 - left)

proc volume*(self: AudioSystem, kind: VolumeKind): float

# SoundId
proc newSoundId(chan: AudioChannel, sndDef: SoundDefinition, cat: SoundCategory, objId: int): SoundId =
  result = SoundId(id: newSoundId(), chan: chan, sndDef: sndDef, cat: cat, objId: objId)

proc update*(self: SoundId, audio: AudioSystem) =
  let objVolume = if self.objId == 0: 1f else: audio.volFunc(self)

  let pan = clamp(self.pan, -1f, 1f)
  self.chan.setPan(pan)

  var volKind: VolumeKind
  case self.cat:
  of Music:
    volKind = vkMusic
  of Sound:
    volKind = vkSound
  of Talk:
    volKind = vkTalk
  let categoryVolume = audio.volume(volKind)
  let masterVolume = audio.volume(vkMaster)
  let volume = masterVolume * categoryVolume * objVolume
  self.chan.volume = volume

# AudioSystem
proc newAudioSystem*(volFunc: VolFunc): AudioSystem =
  result = AudioSystem(volFunc: volFunc, volumes: {vkMaster: 1.0, vkMusic: 1.0, vkSound: 1.0, vkTalk: 1.0}.toTable)
  for i in 0..<result.chans.len:
    result.chans[i] = newAudioChannel(i)
  gAudio = result

proc play*(self: AudioSystem, sndDef: SoundDefinition, cat: SoundCategory, loopTimes = 0; fadeInTimeMs = 0.0, objId = 0): SoundId =
  for chan in self.chans:
    if chan.status() == Stopped:
      sndDef.load()
      chan.buffer = sndDef.buffer
      chan.play(loopTimes, fadeInTimeMs)
      var sound = newSoundId(chan, sndDef, cat, objId)
      self.sounds[chan.id] = sound
      # info fmt"[{chan.id}] loop {loopTimes} {cat} {sndDef.name}"
      return sound
  error "cannot play sound no more channel available"

proc fadeOut*(self: AudioSystem, snd: SoundId, fadeOutTimeSec = 0.0) =
  info fmt"fadeout sound '{snd.sndDef.name}'"
  snd.chan.stop(fadeOutTimeSec)

proc fadeOut*(self: AudioSystem, sndDef: SoundDefinition, fadeOutTimeSec = 0.0) =
  for sound in self.sounds:
    if not sound.isNil and sound.sndDef == sndDef:
      self.fadeOut(sound, fadeOutTimeSec)

proc fadeOut*(self: AudioSystem, fadeOutTimeSec = 0.0) =
  for sound in self.sounds:
    if not sound.isNil and sound.cat == Music:
      self.fadeOut(sound, fadeOutTimeSec)

proc playing*(self: AudioSystem, snd: SoundId): bool =
  not snd.isNil and snd.chan.status() == Playing

proc playing*(self: AudioSystem, snd: SoundDefinition): bool =
  for sound in self.sounds:
    if not sound.isNil and sound.sndDef == snd:
      if self.playing(sound):
        return true
  false

proc stopAll*(self: AudioSystem) =
  for chan in self.chans:
    chan.stop()

proc pauseAll*(self: AudioSystem) =
  for chan in self.chans:
    chan.pause()

proc resumeAll*(self: AudioSystem) =
  for chan in self.chans:
    chan.resume()

proc volume*(self: AudioSystem, snd: SoundId, vol: float) =
  let volume = clamp(vol, 0.0, 1.0)
  snd.chan.volume = volume

proc volume*(self: AudioSystem, sndDef: SoundDefinition, vol: float) =
  let volume = clamp(vol, 0.0, 1.0)
  for sound in self.sounds:
    if not sound.isNil and sound.sndDef == sndDef:
      sound.chan.volume = volume

proc volume*(self: AudioSystem, kind: VolumeKind, vol: float) =
  self.volumes[kind] = vol

proc volume*(self: AudioSystem, kind: VolumeKind): float =
  self.volumes[kind]

proc update*(self: AudioSystem) =
  for soundId in self.sounds:
    if not soundId.isNil:
      soundId.update(self)
      if soundId.chan.status() == Stopped:
        # info fmt"Sound stopped: ch{soundId.chan.id} #{soundId.id} {soundId.sndDef.name}"
        self.sounds[soundId.chan.id] = nil

proc playSoundHover*() =
  if not gAudio.soundHover.isNil:
    discard gAudio.play(gAudio.soundHover, SoundCategory.Sound)
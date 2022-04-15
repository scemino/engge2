import std/logging
import std/streams
import std/strformat
import std/tables
import sdl2
import sdl2/mixer
import ../game/ids
import ../io/ggpackmanager

type
  AudioStatus* = enum
    asStopped,
    asPaused,
    asPlaying
  VolumeKind* = enum
    vkMaster,
    vkMusic,
    vkSound,
    vkTalk,
  AudioChannel = ref object of RootObj
    id*: cint
    numLoops: int
    vol: float
    panning: float
    buffer*: SoundBuffer
  SoundBuffer = ref object of RootObj
    chunk: ptr Chunk
  SoundCategory* = enum
    scMusic,
    scSound,
    scTalk
  SoundDefinition* = ref object of RootObj
    id*: int            # identifier for this sound
    name: string        # name of the sound to load
    buffer: SoundBuffer # buffer containing the sound data
    loaded: bool        # indicates whether or not the sound buffer has been loaded
  SoundId* = ref object of RootObj
    id*: int
    entityId: int
    sndDef: SoundDefinition
    cat: SoundCategory
    chan: AudioChannel
  AudioSystem* = ref object of RootObj
    chans*: array[32, AudioChannel]
    soundDefs*: seq[SoundDefinition]
    sounds*: array[32, SoundId]
    volumes: Table[VolumeKind, float]

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

proc load(self: SoundDefinition) =
  if not self.loaded:
    var data = gGGPackMgr.loadStream(self.name).readAll
    self.buffer.loadMem(data[0].addr, data.len.cint)

# AudioChannel
proc newAudioChannel(channel: Natural): AudioChannel =
  AudioChannel(id: channel.cint, vol: 1.0f)

proc status(self: AudioChannel): AudioStatus =
  if mixer.paused(self.id) == 1:
    checkError()
    asPaused
  elif mixer.playing(self.id) == 1:
    checkError()
    asPlaying
  else:
    asStopped

proc `volume=`*(self: AudioChannel, volume: float) =
  self.vol = volume
  var vol = clamp((volume * 128).int, 0, 128).cint
  discard mixer.volume(self.id, vol)

proc play*(self: AudioChannel; loopTimes = 0; fadeInTimeMs = 0.0) =
  if not self.buffer.isNil:
    case self.status():
    of asPaused:
      info "resume"
      mixer.resume(self.id)
      checkError()
    of asStopped:
      self.numLoops = loopTimes
      if fadeInTimeMs == 0:
        info "playChannel"
        discard mixer.playChannel(self.id, self.buffer.chunk, loopTimes.cint)
        checkError()
      else:
        info "fadeInChannel"
        discard mixer.fadeInChannel(self.id, self.buffer.chunk, loopTimes.cint, fadeInTimeMs.cint)
        checkError()
    of asPlaying:
      return

proc stop*(self: AudioChannel, fadeOutTimeSec = 0.0) =
  if fadeOutTimeSec <= 0.0:
    discard mixer.haltChannel(self.id)
    checkError()
  else:
    discard mixer.fadeOutChannel(self.id, (fadeOutTimeSec * 1000).cint)
    checkError()

proc volume*(self: AudioSystem, kind: VolumeKind): float

# SoundId
proc newSoundId(chan: AudioChannel, sndDef: SoundDefinition, cat: SoundCategory): SoundId =
  result = SoundId(id: newSoundId(), chan: chan, sndDef: sndDef, cat: cat)

proc update*(self: SoundId, audio: AudioSystem) =
  var entityVolume = 1.0
  # TODO: entityVolume
  # var entity = if self.entityId == 0: entity(self.entityId) else: nil
  # if not entity.isNil:
  #   let at = cameraPos()
  #   let room = gEngine.room
  #   entityVolume = if room != entity.room: 0 else: entity.volume

  #   if room == entity.room:
  #     let width = room.screenSize.x;
  #     let diff = abs(at.x - entity.pos.x)
  #     entityVolume = (1.5f - (diff / width)) / 1.5f;
  #     if entityVolume < 0:
  #       entityVolume = 0
  #     let pan = clamp((entity.pos.x - at.x) / (width / 2), -1.0, 1.0)
  #     self.panning = pan

  var volKind: VolumeKind
  case self.cat:
  of scMusic:
    volKind = vkMusic
  of scSound:
    volKind = vkSound
  of scTalk:
    volKind = vkTalk
  let categoryVolume = audio.volume(volKind)
  let masterVolume = audio.volume(vkMaster)
  let volume = masterVolume * categoryVolume * entityVolume
  self.chan.volume = volume

# AudioSystem
proc newAudioSystem*(): AudioSystem =
  new(result)
  result.volumes = {vkMaster: 1.0, vkMusic: 1.0, vkSound: 1.0, vkTalk: 1.0}.toTable
  for i in 0..<result.chans.len:
    result.chans[i] = newAudioChannel(i)

proc play*(self: AudioSystem, sndDef: SoundDefinition, cat: SoundCategory, loopTimes = 0; fadeInTimeMs = 0.0): SoundId =
  for chan in self.chans:
    if chan.status() == asStopped:
      sndDef.load()
      chan.buffer = sndDef.buffer
      chan.play(loopTimes, fadeInTimeMs)
      var sound = newSoundId(chan, sndDef, cat)
      self.sounds[chan.id] = sound
      info fmt"[{chan.id}] loop {loopTimes} {cat} {sndDef.name}"
      return sound
  error "cannot play sound no more channel available"

proc fadeOut*(self: AudioSystem, snd: SoundId, fadeOutTimeSec = 0.0) =
  snd.chan.stop(fadeOutTimeSec)

proc fadeOut*(self: AudioSystem, sndDef: SoundDefinition, fadeOutTimeSec = 0.0) =
  for sound in self.sounds:
    if not sound.isNil and sound.sndDef == sndDef:
      self.fadeOut(sound, fadeOutTimeSec)

proc fadeOut*(self: AudioSystem, fadeOutTimeSec = 0.0) =
  for sound in self.sounds:
    if not sound.isNil and sound.cat == scMusic:
      self.fadeOut(sound, fadeOutTimeSec)

proc playing*(self: AudioSystem, snd: SoundId): bool =
  snd.chan.status() == asPlaying

proc playing*(self: AudioSystem, snd: SoundDefinition): bool =
  for sound in self.sounds:
    if not sound.isNil and sound.sndDef == snd:
      if self.playing(sound):
        return true
  false

proc stopAll*(self: AudioSystem) =
  for chan in self.chans:
    chan.stop()

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
      if soundId.chan.status() == asStopped:
        info fmt"Sound stopped: ch{soundId.chan.id} #{soundId.id} {soundId.sndDef.name}"
        self.sounds[soundId.chan.id] = nil

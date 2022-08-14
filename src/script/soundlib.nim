import std/logging
import std/tables
import sqnim
import vm
import squtils
import ../util/utils
import ../game/room
import ../game/engine
import ../audio/audio
import ../audio/soundtrigger

proc soundVolume(v: HSQUIRRELVM, kind: VolumeKind): SQInteger

proc get(v: HSQUIRRELVM, i: int, value: var SoundDefinition): SQRESULT =
  var id = 0
  result = sq_getinteger(v, i, id)
  value = soundDef(id)

proc getarray(v: HSQUIRRELVM, o: HSQOBJECT, arr: var seq[SoundDefinition]) =
  sq_pushobject(v, o)
  sq_pushnull(v)
  while SQ_SUCCEEDED(sq_next(v, -2)):
    var sound: SoundDefinition
    discard get(v, -1, sound)
    arr.add(sound)
    sq_pop(v, 2)
  sq_pop(v, 1)

proc getarray(v: HSQUIRRELVM, i: int, arr: var seq[SoundDefinition]): SQRESULT =
  var obj: HSQOBJECT
  result = sq_getstackobj(v, i, obj)
  getarray(v, obj, arr)

proc actorSound(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Plays a sound at the specified actor's location.
  ## If no sound is given, then it will turn off the trigger.
  ## If a list of multiple sounds or an array are given, will randomly choose between the sound files.
  ## The triggerNumber says which trigger in the animation JSON file should be used as a trigger to play the sound. 
  var obj = obj(v, 2)
  if obj.isNil:
    return sq_throwerror(v, "failed to get actor or object")
  var trigNum = 0
  if SQ_FAILED(get(v, 3, trigNum)):
    return sq_throwerror(v, "failed to get trigger number")
  let numSounds = sq_gettop(v) - 3
  if numSounds != 0:
    var tmp = 0
    if numSounds == 1 and SQ_SUCCEEDED(get(v, 4, tmp)) and tmp == 0:
      obj.triggers.del trigNum
    else:
      var sounds: seq[SoundDefinition]
      if sq_gettype(v, 4) == OT_ARRAY:
        if SQ_FAILED(getarray(v, 4, sounds)):
          return sq_throwerror(v, "failed to get sounds")
      else:
        sounds.setLen numSounds
        for i in 0..<numSounds:
          discard get(v, 4 + i, sounds[i])

      var trigger = newSoundTrigger(sounds)
      obj.triggers[trigNum] = trigger
  0

proc defineSound(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Defines a sound and binds it to an id.
  ## The defineSound(file) calls should be done at boot and do not load the file.
  ## Its main use is to keep strings from being created and referenced during game play and providing a way to globally change a sound.
  ## .. code-block:: Squirrel
  ## clock_tick <- defineSound("clockTick.wav")
  var filename: string
  if SQ_FAILED(get(v, 2, filename)):
    return sq_throwerror(v, "failed to get filename")
  let sound = newSoundDefinition(filename)
  gEngine.audio.soundDefs.add(sound)
  push(v, sound.id)
  1

proc fadeOutSound(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Fades a sound out over a specified fade out duration (in seconds). 
  ## .. code-block:: Squirrel
  ## fadeOutSound(soundElevatorMusic, 0.5)
  var t: float
  if SQ_FAILED(get(v, 3, t)):
    return sq_throwerror(v, "failed to get fadeOut time")
  let sound = sound(v, 2)
  if not sound.isNil:
    gEngine.audio.fadeOut(sound, t)
  else:
    let soundDef = soundDef(v, 2)
    if soundDef.isNil:
      error "no sound to fadeOutSound"
    else:
      gEngine.audio.fadeOut(soundDef, t)
  0

proc isSoundPlaying(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Returns `TRUE` if sound is currently playing.
  ## Where sound can be a channel (an integer from 1-32), a sound id (as obtained when sound was created with playSound), an actual sound (ie one that has been defined using defineSound).
  ## .. code-block:: Squirrel
  ## if (isSoundPlaying(soundElevatorMusic)) { ...}
  let sound = sound(v, 2)
  if not sound.isNil:
    sq_pushinteger(v, if gEngine.audio.playing(sound): 1 else: 0)
  else:
    let soundDef = soundDef(v, 2)
    if not soundDef.isNil:
      sq_pushinteger(v, if gEngine.audio.playing(soundDef): 1 else: 0)
    else:
      sq_pushinteger(v, 0)
  1

proc playObjectSound(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let nArgs = sq_gettop(v)
  let soundDef = soundDef(v, 2)
  if soundDef.isNil:
    return sq_throwerror(v, "failed to get sound")
  
  let obj = obj(v, 3)
  if obj.isNil:
    return sq_throwerror(v, "failed to get actor or object")
  var loopTimes = 1
  var fadeInTime = 0.0
  if nArgs >= 4:
    discard get(v, 4, loopTimes)
    discard get(v, 5, fadeInTime)

  warn "playObjectSound not fully implemented"
  if not obj.sound.isNil:
    gEngine.audio.fadeOut(obj.sound)
  
  let soundId = gEngine.audio.play(soundDef, Sound, loopTimes, fadeInTime)
  obj.sound = soundId
  let id = if soundId.isNil: 0 else: soundId.id
  push(v, id)
  return 1

proc playSound(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Plays a sound that has been loaded with defineSound(file).
  ## Classifies the audio as "sound" (not "music").
  ## Returns a sound ID that can be used to reference the sound later on.
  ## .. code-block:: Squirrel
  ## playSound(clock_tick)
  ## objectState(quickiePalFlickerLight, ON)
  ## _flourescentSoundID = playSound(soundFlourescentOn)
  let sound = soundDef(v, 2)
  if sound.isNil:
    return sq_throwerror(v, "failed to get sound")
  let soundId = gEngine.audio.play(sound, Sound)
  let id = if soundId.isNil: 0 else: soundId.id
  push(v, id)
  1

proc playSoundVolume(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Starts playing sound at the specified volume, where volume is a float between 0 and 1.
  ## Not for use in adjusting the volume of a sound that is already playing.
  ## Returns a sound ID which can be used when turning off the sound or otherwise manipulating it. 
  ## .. code-block:: Squirrel
  ## script runAway(bunnyActor) {
  ##     local soundVolume = 1.0
  ##     for (local soundVolume = 1.0; x > 0; x -= 0.25) {
  ##         playSoundVolume(soundHop, soundVolume)
  ##         objectOffsetTo(bunnyActor, -10, 0, 0.5)
  ##         breaktime(1.0)
  ##     }
  ## }
  let sound = soundDef(v, 2)
  if sound.isNil:
    return sq_throwerror(v, "failed to get sound")
  var volume = 0.0
  if SQ_FAILED(get(v, 3, volume)):
    return sq_throwerror(v, "failed to get volume")
  var soundId = gEngine.audio.play(sound, Sound)
  let id = if soundId.isNil: 0 else: soundId.id
  if not soundId.isNil:
    gEngine.audio.volume(soundId, volume)
  push(v, id)
  1

proc loadSound(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let sound = soundDef(v, 2)
  if sound.isNil:
    return sq_throwerror(v, "failed to get sound")
  sound.load()
  0

proc loopMusic(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Loops music.
  ## If loopTimes is not defined or is -1, will loop infinitely.
  ## For the first loop, it will fade the sound in for fadeInTime seconds, if specified.
  ## See also loopSound, which classifies the audio as being "sound" not "music".
  ## This is important if we allow separate volume control adjustment. 
  ## .. code-block:: Squirrel
  ## enter = function()
  ## {
  ##     print("Enter StartScreen")
  ##     exCommand(EX_BUTTON_HOVER_SOUND, soundClockTick)
  ##     _music = loopMusic(musicTempA)
  ## }
  let sound = soundDef(v, 2)
  if sound.isNil:
    return sq_throwerror(v, "failed to get music")
  let soundId = gEngine.audio.play(sound, Music, -1)
  let id = if soundId.isNil: 0 else: soundId.id
  push(v, id)
  1

proc loopObjectSound(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  let sound = soundDef(v, 2)
  if sound.isNil:
    return sq_throwerror(v, "failed to get sound")
  let obj = obj(v, 3)
  if obj.isNil:
    return sq_throwerror(v, "failed to get object or actor")
  var loopTimes = -1
  discard get(v, 4, loopTimes)
  var fadeInTime = -1.0
  discard get(v, 5, fadeInTime)
  # TODO: loopObjectSound, add object
  warn "loopObjectSound not fully implemented"
  if not obj.sound.isNil:
    gEngine.audio.fadeOut(obj.sound)
  let soundId = gEngine.audio.play(sound, Sound, loopTimes, fadeInTime)
  obj.sound = soundId
  let id = if soundId.isNil: 0 else: soundId.id
  push(v, id)
  1

proc loopSound(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Loops a sound a specified number of times (loopTimes).
  ## If loopTimes = -1 or not set, then it loops the sound forever.
  ## You can fade in the sound for the first loop by setting the fadeInTime duration (in seconds).
  ## If fadeInTime is 0 or not set, it will immediately be at full volume.
  ## Returns a sound ID which can be used when turning off the sound or otherwise manipulating it.
  ## See also loopMusic. 
  ## .. code-block:: Squirrel
  ## local _muzac = loopSound(soundElevatorMusic, -1, 1.0)
  ## 
  ## script daveCooking() {
  ##     loopSound(soundSizzleLoop)
  ##     ...
  ## }
  ##
  ## if (Bank.bankTelephone.inUse) {
  ##     breaktime(0.5)
  ##     loopSound(soundPhoneBusy, 3)
  ## }
  let sound = soundDef(v, 2)
  if sound.isNil:
    return sq_throwerror(v, "failed to get sound")
  var loopTimes = -1
  discard get(v, 3, loopTimes)
  var fadeInTime = -1.0
  discard get(v, 4, fadeInTime)
  let soundId = gEngine.audio.play(sound, Sound, loopTimes, fadeInTime)
  let id = if soundId.isNil: 0 else: soundId.id
  push(v, id)
  1

proc masterSoundVolume(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  soundVolume(v, vkMaster)

proc musicMixVolume(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  soundVolume(v, vkMusic)

proc playMusic(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Plays the specified music file.
  ## Classifies the audio as "music".
  ## Returns a sound ID which can be used when turning off the sound or otherwise manipulating it.
  ## See also `playSound`. 
  ## .. code-block:: Squirrel
  ## local music = _nextMusic ? _nextMusic : randomfrom(_musicPool)
  ## _nextMusic = 0
  ## print("Playing "+soundAsset(music)+" ("+music+")")
  ## _playingMusicSID = playMusic(music)
  let soundDef = soundDef(v, 2)
  if soundDef.isNil:
    return sq_throwerror(v, "failed to get music")
  var soundId = gEngine.audio.play(soundDef, Music)
  let id = if soundId.isNil: 0 else: soundId.id
  push(v, id)
  1

proc soundMixVolume(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  soundVolume(v, vkSound)

proc soundVolume(v: HSQUIRRELVM, kind: VolumeKind): SQInteger =
  var volume = 0.0
  if sq_gettop(v) == 2:
    if SQ_FAILED(get(v, 2, volume)):
      return sq_throwerror(v, "failed to get volume")
    gEngine.audio.volume(kind, volume)
    return 0
  else:
    push(v, gEngine.audio.volume(kind))
    return 1

proc soundVolume(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Sets the volume (float from 0 to 1) of an already playing sound.
  ## Can be used for a channel (integer 1-32), soundId (as obtained when starting the sound playing) or an actual sound (defined by defineSound).
  ## If _sound is not yet playing, then nothing will happen (if sound is subsequently set to play it will be at full volume). 
  ## .. code-block:: Squirrel
  ## local _tronSoundTID = loopObjectSound(soundTronRattle_Loop, quickieToilet, -1, 0.25)
  ## soundVolume(_tronSoundTID, 0.2)
  ## shakeObject(quickieToilet, 0.25)
  ## jiggleObject(quickieToilet, 0.25)
  ## breaktime(0.2)
  let sound = sound(v, 2)
  var volume = 1.0
  discard get(v, 4, volume)
  if not sound.isNil:
    gEngine.audio.volume(sound, volume)
  else:
    let soundDef = soundDef(v, 2)
    if not soundDef.isNil:
      gEngine.audio.volume(soundDef, volume)
  0

proc stopAllSounds(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Stops all the sounds currently playing.
  gEngine.audio.stopAll()
  0

proc stopMusic(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  var t = 0.0
  discard get(v, 2, t)
  gEngine.audio.fadeOut(t)
  0

proc stopSound(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  ## Immediately stops the indicated sound.
  ## Abruptly. Silently. No fades. It's dead.
  ## Can be used for a channel (integer 1-32), _soundId (as obtained when starting the sound playing) or an actual sound (defined by defineSound).
  ## If using a defined sound, will stop any sound that is named that, eg all cricket sounds (soundCrickets, soundCrickets). 
  ## .. code-block:: Squirrel
  ## stopSound(soundElevatorMusic)
  let sound = sound(v, 2)
  if not sound.isNil:
    gEngine.audio.fadeOut(sound)
  else:
    let soundDef = soundDef(v, 2)
    if not soundDef.isNil:
      gEngine.audio.fadeOut(soundDef)
  0

proc talkieMixVolume(v: HSQUIRRELVM): SQInteger {.cdecl.} =
  soundVolume(v, vkTalk)

proc register_sndlib*(v: HSQUIRRELVM) =
  ## Registers the game sound library.
  ## 
  ## It adds all the sound functions in the given Squirrel virtual machine `v`.
  v.regGblFun(actorSound, "actorSound")
  v.regGblFun(defineSound, "defineSound")
  v.regGblFun(fadeOutSound, "fadeOutSound")
  v.regGblFun(isSoundPlaying, "isSoundPlaying")
  v.regGblFun(loadSound, "loadSound")
  v.regGblFun(loopMusic, "loopMusic")
  v.regGblFun(loopObjectSound, "loopObjectSound")
  v.regGblFun(loopSound, "loopSound")
  v.regGblFun(masterSoundVolume, "masterSoundVolume")
  v.regGblFun(musicMixVolume, "musicMixVolume")
  v.regGblFun(playMusic, "playMusic")
  v.regGblFun(playObjectSound, "playObjectSound")
  v.regGblFun(playSound, "playSound")
  v.regGblFun(playSoundVolume, "playSoundVolume")
  v.regGblFun(soundMixVolume, "soundMixVolume")
  v.regGblFun(soundVolume, "soundVolume")
  v.regGblFun(stopAllSounds, "stopAllSounds")
  v.regGblFun(stopMusic, "stopMusic")
  v.regGblFun(stopSound, "stopSound")
  v.regGblFun(talkieMixVolume, "talkieMixVolume")

# TODO

* [x] debug tools (dear imgui)
  * [ ] actors
  * [ ] camera
  * [x] console
  * [ ] general
  * [ ] objects
  * [ ] preferences
  * [ ] room
  * [x] textures
  * [ ] vm
  * [x] threads
  * [x] sounds
* [x] actor costume
* [x] actor animations
* [x] actor walking
  * [x] path finding
  * [x] animation
  * [x] animation offsets
  * [x] zsort
  * [x] scaling
  * [x] walk facing
  * [x] final facing
* [x] lips
* [x] blink
* [ ] input
* [ ] input mapping
* [x] walkboxes
* [ ] dialogs
* [ ] HUD
* [ ] savegames
* [ ] achievements
* [ ] UI dialogs
* [ ] shaders
* [ ] preferences
* [x] actor talking
* [x] audio
* [x] squirrel bindings
* [x] easy squirrel constants bindings
* [x] change thread management in order to use only 1 thread
* [x] resource management
* [x] ref counting with resource management
* [x] test object hierarchy: scene graph ?
* [x] text

# Functions

## Actor

- [x] actorAlpha
- [x] actorAnimationNames
- [ ] actorAnimationFlags
- [x] actorAt
- [x] actorBlinkRate
- [x] actorColor
- [x] actorCostume
- [x] actorDistanceTo
- [x] actorDistanceWithin
- [x] actorFace
- [x] actorHidden
- [x] actorHideLayer
- [x] actorInTrigger
- [x] actorInWalkbox
- [x] actorLockFacing
- [x] actorPlayAnimation
- [x] actorPosX
- [x] actorPosY
- [x] actorRenderOffset
- [x] actorRoom
- [x] actorShowLayer
- [x] actorSlotSelectable
- [x] actorStand
- [x] actorStopWalking
- [x] actorTalkColors
- [x] actorTalking
- [x] actorTalkOffset
- [x] actorTurnTo
- [x] actorUsePos
- [x] actorUseWalkboxes
- [x] actorVolume
- [x] actorWalking
- [x] actorWalkForward
- [x] actorWalkSpeed
- [x] actorWalkTo
- [x] addSelectableActor
- [x] createActor
- [ ] flashSelectableActor
- [x] isActorOnScreen
- [x] isActorSelectable
- [x] is_actor
- [x] masterActorArray
- [x] mumbleLine
- [x] sayLine
- [ ] sayLineAt
- [x] selectActor
- [ ] stopTalking
- [x] triggerActors
- [x] verbUIColors

## General

- [ ] activeVerb
- [ ] adhocalytics
- [x] arrayShuffle
- [x] assetExists
- [x] cameraAt
- [ ] cameraBounds
- [ ] cameraFollow
- [x] cameraInRoom
- [x] cameraPanTo
- [x] cameraPos
- [x] chr
- [x] cursorPosX
- [x] cursorPosY
- [ ] cutscene
- [ ] cutsceneOverride
- [ ] distance
- [ ] exCommand EX_ALLOW_SAVEGAMES, EX_POP_CHARACTER_SELECTION, EX_AUTOSAVE, EX_AUTOSAVE_STATE, EX_BUTTON_HOVER_SOUND, EX_CAMERA_TRACKING, EX_FORCE_TALKIE_TEXT, EX_IDLE_TIME, EX_OPTIONS_MUSIC, EX_RESTART, EX_SHOW_OPTIONS
- [ ] findScreenPosition
- [ ] frameCounter
- [ ] in_array
- [ ] incutscene
- [ ] indialog
- [ ] inputVerbs
- [x] is_array
- [x] is_function
- [x] is_string
- [x] is_table
- [x] loadArray
- [ ] markAchievement
- [ ] markProgress
- [ ] markStat
- [x] ord
- [ ] pushSentence
- [x] random
- [x] randomfrom
- [x] randomOdds
- [x] randomodds
- [x] randomseed
- [ ] refreshUI
- [x] screenSize
- [ ] setAmbientLight
- [ ] setDebugger
- [x] setVerb
- [ ] startDialog
- [ ] stopSentence
- [x] strcount
- [x] strcrc
- [x] strfind
- [x] strfirst
- [x] strlines
- [x] strreplace
- [x] strsplit
- [x] translate

## Room

- [x] addCallback
- [x] addTrigger
- [ ] clampInWalkbox
- [x] createLight
- [x] lightBrightness
- [x] lightConeAngle
- [x] lightConeDirection
- [x] lightConeFalloff
- [x] lightCutOffRadius
- [x] lightHalfRadius
- [x] lightTurnOn
- [x] lightZRange
- [x] definePseudoRoom
- [x] defineRoom
- [x] enableTrigger
- [x] enterRoomFromDoor
- [x] findRoom
- [x] masterRoomArray
- [x] removeCallback
- [x] removeTrigger
- [x] roomActors
- [ ] roomEffect
- [x] roomFade
- [x] roomLayer
- [x] roomOverlayColor
- [x] roomRotateTo
- [x] roomSize
- [x] walkboxHidden

## System

- [x] activeController
- [x] addFolder
- [x] breakhere
- [x] breaktime
- [x] breakwhileanimating
- [ ] breakwhilecamera
- [ ] breakwhilecutscene
- [ ] breakwhiledialog
- [ ] breakwhileinputoff
- [x] breakwhilerunning
- [x] breakwhilesound
- [x] breakwhiletalking
- [x] breakwhilewalking
- [x] dumpvar
- [x] gameTime
- [ ] getPrivatePref
- [ ] getUserPref
- [x] include
- [x] inputHUD
- [x] inputOff
- [x] inputOn
- [x] inputSilentOff
- [x] inputState
- [x] inputController
- [x] isInputOn
- [x] logEvent
- [x] logInfo
- [x] logWarning
- [x] microTime
- [ ] moveCursorTo
- [x] rawsafeget
- [ ] setPrivatePref
- [ ] setUserPref
- [x] startglobalthread
- [x] startthread
- [x] stopthread
- [x] threadid
- [x] threadpauseable

## Object

- [x] createObject 
- [x] createTextObject
- [x] deleteObject
- [x] findObjectAt
- [x] is_object
- [ ] isInventoryOnScreen
- [x] isObject
- [ ] jiggleInventory
- [ ] jiggleObject
- [x] loopObjectState
- [x] objectAlpha
- [x] objectAlphaTo
- [x] objectAt
- [x] objectBumperCycle
- [ ] objectCenter
- [x] objectColor
- [ ] objectDependentOn
- [x] objectFPS
- [x] objectHidden
- [x] objectHotspot
- [x] objectIcon
- [x] objectLit
- [x] objectMoveTo
- [x] objectOffset
- [x] objectOffsetTo
- [x] objectOwner
- [x] objectParallaxLayer
- [x] objectParent
- [x] objectPosX
- [x] objectPosY
- [ ] objectRenderOffset
- [x] objectRoom
- [x] objectRotate
- [x] objectRotateTo
- [x] objectScale
- [x] objectScaleTo
- [x] objectScreenSpace
- [ ] objectShader
- [x] objectSort
- [x] objectState
- [x] objectTouchable
- [x] objectUsePos
- [x] objectUsePosX
- [x] objectUsePosY
- [x] objectValidUsePos
- [x] objectValidVerb
- [x] pickupObject
- [ ] pickupReplacementObject
- [x] playObjectState
- [ ] popInventory
- [ ] removeInventory
- [x] setDefaultObject
- [ ] shakeObject
- [ ] stopObjectMotors

## Sound

- [x] actorSound
- [x] defineSound
- [x] fadeOutSound
- [x] isSoundPlaying
- [ ] loadSound
- [x] loopMusic
- [ ] loopObjectSound
- [x] loopSound
- [x] masterSoundVolume
- [x] musicMixVolume
- [x] playMusic
- [ ] playObjectSound
- [x] playSound
- [x] playSoundVolume
- [x] soundMixVolume
- [x] soundVolume
- [x] stopAllSounds
- [x] stopMusic
- [x] stopSound
- [x] talkieMixVolume

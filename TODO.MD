# TODO

* [ ] dear imgui
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
* [ ] blink
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
- [ ] actorAnimationNames
- [ ] actorAnimationFlags
- [x] actorAt
- [ ] actorBlinkRate
- [x] actorColor
- [x] actorCostume
- [ ] actorDistanceTo
- [ ] actorDistanceWithin
- [x] actorFace
- [x] actorHidden
- [x] actorHideLayer
- [ ] actorInTrigger
- [ ] actorInWalkbox
- [x] actorLockFacing
- [x] actorPlayAnimation
- [x] actorPosX
- [x] actorPosY
- [x] actorRenderOffset
- [x] actorRoom
- [x] actorShowLayer
- [x] actorSlotSelectable
- [ ] actorStand
- [ ] actorStopWalking
- [x] actorTalkColors
- [x] actorTalking
- [x] actorTalkOffset
- [ ] actorTurnTo
- [ ] actorUsePos
- [x] actorUseWalkboxes
- [x] actorVolume
- [ ] actorWalking
- [ ] actorWalkForward
- [x] actorWalkSpeed
- [x] actorWalkTo
- [x] addSelectableActor
- [x] createActor
- [ ] flashSelectableActor
- [x] isActorOnScreen
- [ ] isActorSelectable
- [x] is_actor
- [x] masterActorArray
- [x] mumbleLine
- [x] sayLine
- [ ] sayLineAt
- [x] selectActor
- [ ] stopTalking
- [ ] triggerActors
- [x] verbUIColors

## General

- [ ] activeVerb
- [ ] adhocalytics
- [ ] arrayShuffle
- [x] assetExists
- [x] cameraAt
- [ ] cameraBounds
- [ ] cameraFollow
- [x] cameraInRoom
- [x] cameraPanTo
- [x] cameraPos
- [x] chr
- [ ] cursorPosX
- [ ] cursorPosY
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
- [ ] strcount
- [ ] strcrc
- [ ] strfind
- [ ] strfirst
- [ ] strlast
- [ ] strlines
- [ ] strreplace
- [ ] strsplit
- [ ] translate

## Room

- [x] addCallback
- [ ] addTrigger
- [ ] clampInWalkbox
- [ ] createLight, lightBrightness, lightConeDirection, lightConeAngle, lightConeFalloff, lightCutOffRadius, lightHalfRadius, lightTurnOn, lightZRange
- [ ] definePseudoRoom
- [x] defineRoom
- [ ] enableTrigger
- [ ] enterRoomFromDoor
- [ ] findRoom
- [x] masterRoomArray
- [x] removeCallback
- [ ] removeTrigger
- [x] roomActors
- [ ] roomEffect
- [x] roomFade
- [x] roomLayer
- [x] roomOverlayColor
- [ ] roomRotateTo
- [ ] roomSize
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
- [ ] include
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
- [ ] findObjectAt
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
- [ ] objectIcon
- [ ] objectLit
- [x] objectMoveTo
- [x] objectOffset
- [x] objectOffsetTo
- [ ] objectOwner
- [x] objectParallaxLayer
- [ ] objectParent
- [x] objectPosX
- [x] objectPosY
- [ ] objectRenderOffset
- [x] objectRoom
- [x] objectRotate
- [x] objectRotateTo
- [x] objectScale
- [ ] objectScaleTo
- [x] objectScreenSpace
- [ ] objectShader
- [x] objectSort
- [x] objectState
- [x] objectTouchable
- [ ] objectUsePos
- [ ] objectUsePosX
- [ ] objectUsePosY
- [ ] objectValidUsePos
- [ ] objectValidVerb
- [ ] pickupObject
- [ ] pickupReplacementObject
- [x] playObjectState
- [ ] popInventory
- [ ] removeInventory
- [ ] setDefaultObject
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

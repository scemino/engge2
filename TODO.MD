# TODO

* [ ] dear imgui
* [ ] actor costume
* [ ] actor animations
* [ ] actor walking
* [ ] actor talking
* [ ] actor scaling
* [ ] lips
* [ ] blink
* [ ] input
* [ ] input mapping
* [ ] walkboxes
* [ ] dialogs
* [ ] HUD
* [ ] savegames
* [ ] achievements
* [ ] UI dialogs
* [ ] shaders
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
- [ ] actorPosX, actorPosY
- [x] actorRenderOffset
- [ ] actorRoom
- [x] actorShowLayer
- [ ] actorSlotSelectable
- [ ] actorStand
- [ ] actorStopWalking
- [ ] actorTalkColors
- [ ] actorTalking
- [ ] actorTalkOffset
- [ ] actorTurnTo
- [ ] actorUsePos
- [x] actorUseWalkboxes
- [x] actorVolume
- [ ] actorWalking
- [ ] actorWalkForward
- [x] actorWalkSpeed
- [x] actorWalkTo
- [ ] addSelectableActor
- [x] createActor
- [ ] flashSelectableActor
- [ ] isActorOnScreen
- [ ] isActorSelectable
- [ ] masterActorArray
- [ ] mumbleLine
- [ ] sayLine
- [ ] sayLineAt
- [ ] selectActor
- [ ] stopSentence
- [ ] stopTalking
- [ ] triggerActors

## General

- [ ] adhocalytics
- [ ] addTrigger
- [ ] arrayShuffle
- [x] assetExists
- [x] cameraAt
- [ ] cameraBounds
- [ ] cameraFollow
- [x] cameraInRoom
- [x] cameraPanTo
- [x] cameraPos
- [x] chr
- [ ] clampInWalkbox
- [ ] createLight, lightBrightness, lightConeDirection, lightConeAngle, lightConeFalloff, lightCutOffRadius, lightHalfRadius, lightTurnOn, lightZRange
- [ ] cursorPosX
- [ ] cursorPosY
- [ ] cutscene
- [ ] cutsceneOverride
- [ ] distance
- [ ] enableTrigger
- [ ] exCommand EX_ALLOW_SAVEGAMES, EX_POP_CHARACTER_SELECTION, EX_AUTOSAVE, EX_AUTOSAVE_STATE, EX_BUTTON_HOVER_SOUND, EX_CAMERA_TRACKING, EX_FORCE_TALKIE_TEXT, EX_IDLE_TIME, EX_OPTIONS_MUSIC, EX_RESTART, EX_SHOW_OPTIONS
- [ ] findScreenPosition
- [ ] frameCounter
- [ ] getPrivatePref, setPrivatePref
- [ ] getUserPref, setUserPref
- [ ] in_array
- [ ] incutscene
- [ ] indialog
- [ ] inputHUD
- [ ] inputOff
- [ ] inputOn
- [ ] inputSilentOff
- [ ] inputState
- [ ] inputVerbs
- [x] is_array
- [x] is_function
- [x] is_string
- [x] is_table
- [ ] isInputOn
- [ ] isInventoryOnScreen
- [ ] jiggleInventory
- [x] loadArray
- [ ] markAchievement
- [ ] markProgress
- [ ] markStat
- [ ] moveCursorTo
- [x] ord
- [ ] pickupObject
- [ ] pickupReplacementObject
- [ ] popInventory
- [ ] pushSentence
- [x] random
- [x] randomfrom
- [x] randomOdds
- [x] randomodds
- [x] randomseed
- [ ] refreshUI
- [ ] removeInventory
- [ ] removeTrigger
- [x] screenSize
- [ ] setAmbientLight
- [ ] setDebugger
- [ ] setVerb
- [ ] startDialog
- [ ] strcount
- [ ] strcrc
- [ ] strfind
- [ ] strfirst
- [ ] strlast
- [ ] strlines
- [ ] strreplace
- [ ] strsplit
- [ ] translate
- [ ] verbUIColors

## Room

- [ ] definePseudoRoom
- [x] defineRoom
- [ ] enterRoomFromDoor
- [ ] findRoom
- [x] masterRoomArray
- [x] roomActors
- [ ] roomEffect
- [x] roomFade
- [x] roomLayer
- [x] roomOverlayColor
- [ ] roomRotateTo
- [ ] roomSize
- [ ] walkboxHidden

## System

- [x] activeController
- [x] addCallback
- [x] addFolder
- [x] breakhere
- [x] breaktime
- [x] breakwhileanimating
- [ ] breakwhilecamera
- [ ] breakwhilecutscene
- [ ] breakwhiledialog
- [x] breakwhilerunning
- [x] breakwhilesound
- [ ] breakwhiletalking
- [x] breakwhilewalking
- [x] gameTime
- [x] inputController
- [x] logEvent
- [x] logInfo
- [x] logWarning
- [x] microTime
- [x] removeCallback
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
- [x] isObject
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
- [ ] objectScreenSpace
- [ ] objectShader
- [x] objectSort
- [x] objectState
- [x] objectTouchable
- [ ] objectUsePos
- [ ] objectUsePosX
- [ ] objectUsePosY
- [ ] objectValidUsePos
- [ ] objectValidVerb
- [x] playObjectState
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

# Engge II

## TODO

* [ ] camera
    * [ ] advanced camera movement
    * [x] camera follow actor
    * [x] camera pan
* [ ] input
  * [ ] input mapping
* [ ] cutscene
  * [ ] cutscene override
  * [ ] cutscene UI (ESC)
* [ ] dialogs
  * [ ] yack intepreter
  * [x] yack parsing
* [ ] HUD
  * [ ] sentence
  * [ ] scroll inventory
  * [ ] fade
  * [ ] mouse text repositioned
  * [ ] mouse zsort
  * [ ] actor selection
  * [x] verbs
  * [x] inventory
  * [x] mouse cursor
* [ ] triggers
  * [ ] room trigger should be called in a thread (to be breakable)
* [ ] pause game
* [ ] savegames
* [ ] achievements
* [ ] UI dialogs
* [ ] shaders
* [ ] continuous integration
* [ ] preferences
  * [ ] private preferences (achievement)
  * [x] user preferences
  * [x] temp preferences (debug)
* [ ] sentence
  * [ ] cursor verb should be reset (walk to) when action is executed or cancelled
* [x] debug tools (dear imgui)
  * [x] console
  * [x] general
  * [x] objects
  * [x] actors
  * [x] room
  * [x] textures
  * [x] threads
  * [x] sounds
* [ ] actor
  * [ ] actor reach animation
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
    * [x] walkboxes
  * [x] actor lips
  * [x] actor blink
  * [x] actor talking
  * [x] actor walk fast
* [ ] audio
  * [ ] sound position
  * [x] talk
  * [x] sound
  * [x] music
* [x] script
  * [x] squirrel bindings
  * [x] easy squirrel constants bindings
  * [x] change thread management in order to use only 1 thread
* [ ] resource management
  * [ ] ref counting with resource management
* [x] test object hierarchy: scene graph ?
* [x] text

## Functions

### Actor

- [x] actorAlpha
- [x] actorAnimationNames
- [x] actorAnimationFlags
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
- [x] stopTalking
- [x] triggerActors
- [x] verbUIColors

### General

- [x] activeVerb
- [ ] adhocalytics
- [x] arrayShuffle
- [x] assetExists
- [x] cameraAt
- [x] cameraBounds
- [x] cameraFollow
- [x] cameraInRoom
- [x] cameraPanTo
- [x] cameraPos
- [x] chr
- [x] cursorPosX
- [x] cursorPosY
- [x] cutscene
- [ ] cutsceneOverride
- [ ] distance
- [ ] exCommand EX_ALLOW_SAVEGAMES
- [ ] exCommand EX_POP_CHARACTER_SELECTION
- [ ] exCommand EX_AUTOSAVE
- [ ] exCommand EX_AUTOSAVE_STATE
- [ ] exCommand EX_BUTTON_HOVER_SOUND
- [ ] exCommand EX_CAMERA_TRACKING
- [ ] exCommand EX_FORCE_TALKIE_TEXT
- [ ] exCommand EX_IDLE_TIME
- [ ] exCommand EX_OPTIONS_MUSIC
- [ ] exCommand EX_RESTART
- [ ] exCommand EX_SHOW_OPTIONS
- [ ] findScreenPosition
- [ ] frameCounter
- [ ] in_array
- [x] incutscene
- [ ] indialog
- [x] inputVerbs
- [ ] int
- [x] is_array
- [x] is_function
- [x] is_string
- [x] is_table
- [x] loadArray
- [ ] markAchievement
- [ ] markProgress
- [ ] markStat
- [x] ord
- [x] pushSentence
- [x] random
- [x] randomfrom
- [x] randomOdds
- [x] randomodds
- [x] randomseed
- [ ] refreshUI
- [x] screenSize
- [x] setAmbientLight
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

### Room

- [x] addCallback
- [x] addTrigger
- [x] clampInWalkbox
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
  - [x] EFFECT_NONE
  - [x] EFFECT_SEPIA
  - [ ] EFFECT_EGA
  - [ ] EFFECT_VHS
  - [ ] EFFECT_GHOST
  - [x] EFFECT_BLACKANDWHITE
- [x] roomFade
- [x] roomLayer
- [x] roomOverlayColor
- [x] roomRotateTo
- [x] roomSize
- [x] walkboxHidden

### System

- [x] activeController
- [x] addFolder
- [x] breakhere
- [x] breaktime
- [x] breakwhileanimating
- [x] breakwhilecamera
- [x] breakwhilecutscene
- [ ] breakwhiledialog
- [x] breakwhileinputoff
- [x] breakwhilerunning
- [x] breakwhilesound
- [x] breakwhiletalking
- [x] breakwhilewalking
- [x] dumpvar
- [x] gameTime
- [ ] getPrivatePref
- [x] getUserPref
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

### Object

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
- [x] objectCenter
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
- [x] removeInventory
- [x] setDefaultObject
- [ ] shakeObject
- [ ] stopObjectMotors

### Sound

- [x] actorSound
- [x] defineSound
- [x] fadeOutSound
- [x] isSoundPlaying
- [x] loadSound
- [x] loopMusic
- [x] loopObjectSound
- [x] loopSound
- [x] masterSoundVolume
- [x] musicMixVolume
- [x] playMusic
- [x] playObjectSound
- [x] playSound
- [x] playSoundVolume
- [x] soundMixVolume
- [x] soundVolume
- [x] stopAllSounds
- [x] stopMusic
- [x] stopSound
- [x] talkieMixVolume

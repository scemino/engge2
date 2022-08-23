# Engge II

## Known Bugs

* [ ] wrong actor placement during give animation
* [ ] inventory icon is all white
* [ ] empty inventory icon has 1 white pixel
* [x] menu hotspot is wrong
* [x] inventory hotspot is wrong
* [x] dialog choice hotspot is wrong
* [x] invalid talk offset (with pigeon brothers for example)
* [x] wheels are missing in pigeons van
* [x] when actor is switched, the verb colors are wrong
* [x] after a cutscene, the current room is not where the actor is
* [x] sheriff animation flip_coin3 crashs 
* [x] objectAlphaTo can be called with null as argument
* [x] invalid room size
* [x] when using camera on cadaver, the actor says there is no more film inside
* [x] an actor can give something to itself
* [x] dialog text can contains this \" instead of "
* [x] when using a door, the actor is no more in the current room
* [x] crash with "trying to set 'thread'"
* [x] actor's head is 1 pixel offset
* [x] walk fast does not work
* [x] bug use verb mouse down
* [x] layer 1 pixel offset :(
* [x] tutorial objects are in background
* [x] cursor text is too big
* [x] some triggers don't work

## TODO

* [ ] HUD
  * [ ] actor selection
  * [ ] fade
  * [ ] mouse text repositioned
  * [ ] sentence
    * [ ] use lookat verb for inventory object 
    * [x] use flag: with, in, on
    * [x] use flag: giveto
  * [x] mouse zsort
  * [x] verbs
  * [x] scroll inventory
  * [x] inventory
  * [x] mouse cursor
* [ ] UI dialogs
  * [x] main menu
  * [ ] options
    * [ ] Save game
    * [x] Load game
    * [x] Sound
    * [x] Video
    * [x] Controls
    * [x] Text & Speech
    * [ ] Help
  * [x] pause game
  * [x] quit game
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
  * [x] actor blink
  * [x] actor talking
    * [x] actor lips movement
    * [x] change state if in {}
    * [x] replace \" by "
    * [x] ignore text if in ()
    * [x] ignore #M or #F at the end of a text
    * [x] sound
  * [x] actor walk fast
* [ ] audio
  * [ ] sound position
  * [x] talk
  * [x] sound
  * [x] music
* [ ] dialogs
  * [ ] choice anim
  * [ ] choice slide when too long
  * [ ] expressions
    * [ ] waitfor
    * [ ] allow objects
    * [ ] override
    * [x] goto
    * [x] code
    * [x] choice
    * [x] say
    * [x] pause
    * [x] dialog
    * [x] shutup
    * [x] waitwhile
    * [x] limit
    * [x] parrot
  * [x] conditions
    * [x] code
    * [x] once
    * [x] show once
    * [x] once ever
    * [x] temp once
  * [x] yack intepreter
  * [x] yack parsing
  * [x] draw choices
  * [x] allow to choose a sentence
  * [x] hide choices after having chosen a sentence
  * [x] disable input during dialog
  * [x] use actor colors
  * [x] hide cursor text* [ ] achievements
* [ ] input
  * [ ] input mapping
* [ ] cutscene
  * [ ] cutscene UI (ESC)
  * [x] cutscene override
* [ ] preferences
  * [ ] private preferences (achievement)
  * [x] user preferences
  * [x] temp preferences (debug)
* [ ] camera
    * [ ] advanced camera movement
    * [x] camera follow actor
    * [x] camera pan
* [ ] shaders
* [ ] debug tools (dear imgui)
  * [ ] preferences to enable debug tools
  * [ ] shortcuts to show/hode
  * [ ] console
    * [ ] dump variables
    * [x] input
    * [x] log
  * [x] general
  * [x] objects
  * [x] actors
  * [x] room
  * [x] textures
  * [x] threads
  * [x] sounds
* [ ] resource management
  * [ ] ref counting with resource management
  * [x] if a resource name contains "_en" then replace by the selected language: texture, spritesheet, ThimbleweedText_en.tsv, loadArray
* [x] triggers
  * [x] room trigger should be called in a thread (to be breakable)
* [x] sentence
  * [x] cursor verb should be reset (walk to) when action is executed or cancelled
* [ ] logging
  * [ ] add colors to console
  * [x] file log: ng.log (all levels) and errors.log (only for warnings and errors)
  * [x] console
  * [x] debug tool console
* [x] script
  * [x] squirrel bindings
  * [x] easy squirrel constants bindings
  * [x] change thread management in order to use only 1 thread
* [x] test object hierarchy: scene graph ?
* [x] text
  * [x] horizontal alignment
  * [x] vertical alignment
* [x] continuous integration

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
- [x] distance
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
- [x] findScreenPosition
- [x] frameCounter
- [ ] getPrivatePref
- [x] getUserPref
- [x] in_array
- [x] incutscene
- [x] indialog
- [x] inputVerbs
- [x] int
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
- [ ] setPrivatePref
- [ ] setUserPref
- [x] setVerb
- [x] startDialog
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
- [x] breakwhiledialog
- [x] breakwhileinputoff
- [x] breakwhilerunning
- [x] breakwhilesound
- [x] breakwhiletalking
- [x] breakwhilewalking
- [x] cutscene
- [x] cutsceneOverride
- [x] dumpvar
- [x] gameTime
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
- [x] isInventoryOnScreen
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
- [x] objectDependentOn
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
- [x] objectRenderOffset
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
- [x] pickupReplacementObject
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

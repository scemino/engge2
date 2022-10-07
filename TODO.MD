# Engge II

## Known Bugs

* [ ] when we use the notebook, the text is not at the correct position
* [ ] wrong actor placement during give animation
* [ ] in closeup room, go to the options menus, savegame should be disabled
* [ ] music and sounds are interrupted
* [ ] actor still walks when switching actors
* [ ] actor in countymap does not follow the path
* [x] hide sentence when HUD in not visible
* [x] verb is not reset when executed
* [x] all actor's text are White
* [x] actors don't respect useWalkboxes
* [x] when franklin enters in the Hotel's lobby, Reyes should not be visible
* [x] actor does not climb but walk on the ladder
* [x] we don't see Chuck in the tvs in LaserHall
* [x] PillowTronEndDialog never ends
* [x] sayLine crash with an array
* [x] Franklin cannot go through doors
* [x] Ransome cannot give the floppy disk to Delores
* [x] Chuck computer text is not translated
* [x] Clara in the elevator should not be visible
* [x] cannot press buttons in the elevator
* [x] Franklin cannot put on his glasses
* [x] wrong number of args when opening elevator
* [x] actor is not visible in countymap
* [x] no camera pan in the hotel
* [x] actor is not moving in countymap
* [x] crash when using countymap
* [x] when using copytron, the game is frozen
* [x] if you take once the map in the Nickel news then you can't leave the room
* [x] hide debug tools by default and allow toggle
* [x] it's not possible to give the letter to chuck
* [x] Delores dance never ends
* [x] Delores dance is buggy
* [x] Fix delores using letter on mailbox
* [x] ransome can't pickup his money in the safe (again)
* [x] loading a game can crash when loading selectableActors
* [x] fix camera position when delores use doors in the mansion hall
* [x] (drinking sound)sip sip sip sip in dialog
* [x] Ransome has no face when using gel
* [x] Ransome loses his makeup
* [x] Ransome can't take his makeup
* [x] Ransome can't give his money to Carney
* [x] not possible to pickup money in ransome trailer
* [x] change actor's facing do nothing
* [x] lips don't move anymore
* [x] we should reset actor's follow during cutscene
* [x] we shouldn't see cursor during cutscene
* [x] crash if sayline with only space characters
* [x] sometimes when actor is walking, the actor stops but the animation walking is still running
* [x] actor sometimes disappears
* [x] actor switcher should be not available during cutscene
* [x] actor switcher should be not available during dialog
* [x] dialog with coroner is never ending
* [x] some inventory objects are empty
* [x] empty inventory icon has 1 white pixel
* [x] inventory icon is all white
* [x] walkto keep the actor in memory stack
* [x] when walk down or up, we should see the face or back of the actor
* [x] after loading a savegame actors aren't visible
* [x] {notalk} makes the actor disappear
* [x] in closeup room the actor switcher should allow to go to the options menus, actors are disabled
* [x] when we are in a closeup room, we can still move the current actor
* [x] when we talk to Sandy, the actor is walking to the wrong spot
* [x] when we talk to Sandy, the dialog stops before the end
* [x] when walking the actor is wearing a hat sometimes ???
* [x] script error when using agent badge
* [x] selecting an actor does not switch room
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

* [ ] UI dialogs
  * [ ] Options
    * [ ] Help
      * [ ] Intro            (back: back to options even from mainmenu)
      * [ ] Mouse tips       (back: back to options even from mainmenu)
      * [ ] Controller tips  (back: back to options even from mainmenu)
      * [ ] Controller map   (back: back to options even from mainmenu)
      * [ ] Keyboard map     (back: back to options even from mainmenu)
    * [x] Save game (enabled only in game)
    * [x] Load game (back: go back to main menu or game)
    * [x] Sound
    * [x] Video
    * [x] Controls
    * [x] Text & Speech
  * [x] the background is greyed out (and is inactive)
  * [x] Main menu (StartScreen) does not pause game
  * [x] pause game (cursor is changed)
  * [x] quit game (is over options, background is darker, no: go back to main menu or options)
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
    * [x] talking speed should be adjustable
    * [x] actor lips movement
    * [x] change state if in {}
    * [x] replace \" by "
    * [x] ignore text if in ()
    * [x] ignore #M or #F at the end of a text
    * [x] sound
  * [x] actor walk fast
* [ ] dialogs
  * [ ] choice anim
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
  * [x] choice slide when too long
  * [x] yack intepreter
  * [x] yack parsing
  * [x] draw choices
  * [x] allow to choose a sentence
  * [x] hide choices after having chosen a sentence
  * [x] disable input during dialog
  * [x] use actor colors
  * [x] hide cursor text* [ ] achievements
* [ ] input
  * [ ] verbs shortcuts
  * [ ] command handlers
    * [ ] ToggleHud
    * [x] ShowHotspot
    * [x] ToggleDebug
    * [x] PauseGame
    * [x] SkipCutscene
    * [x] SkipText
    * [x] ShowOptions
    * [x] SelectChoice1
    * [x] SelectChoice2
    * [x] SelectChoice3
    * [x] SelectChoice4
    * [x] SelectChoice5
    * [x] SelectChoice6
    * [x] SelectActor1
    * [x] SelectActor2
    * [x] SelectActor3
    * [x] SelectActor4
    * [x] SelectActor5
    * [x] SelectActor6
    * [x] SelectPreviousActor
    * [x] SelectNextActor
  * [x] input mapping
* [ ] preferences
  * [ ] private preferences (achievement)
  * [x] user preferences
  * [x] temp preferences (debug)
* [ ] camera
    * [ ] advanced camera movement
    * [x] camera follow actor
    * [x] camera pan
* [ ] shaders
  * [ ] lighting shader
  * [ ] object shader
  * [x] room effects
    * [x] EGA
    * [x] VHS
    * [x] b/w
    * [x] sepia
    * [x] ghost
  * [x] room fade
    * [x] IN
    * [x] OUT
    * [x] WOBBLE
    * [x] WOBBLE sepia
  * [x] verb shader
* [ ] HUD
  * [ ] fade
  * [ ] actor selection
    * [ ] fade transition when switchin actors
    * [x] actor switch
  * [x] verbs
    * [x] highlight default verb
    * [x] draw verbs
  * [x] mouse text repositioned
  * [x] when sentence is set to classic the cursor change over objects/actors
  * [x] inventory
    * [x] scroll
    * [x] inventory item animation
  * [x] mouse zsort
  * [x] mouse cursor
* [ ] logging
  * [ ] add colors to console
  * [x] file log: ng.log (all levels) and errors.log (only for warnings and errors)
  * [x] console
  * [x] debug tool console
* [ ] resource management
  * [ ] ref counting with resource management
  * [x] if a resource name contains "_en" then replace by the selected language: texture, spritesheet, ThimbleweedText_en.tsv, loadArray
* [x] sentence
  * [x] classic sentence
  * [x] use lookat verb for inventory object
  * [x] use flag: with, in, on
  * [x] use flag: giveto
  * [x] cursor verb should be reset (walk to) when action is executed or cancelled
* [x] debug tools (dear imgui)
  * [x] shortcuts to show/hide
  * [x] preferences to enable debug tools
  * [x] console
    * [x] dump variables
    * [x] input
    * [x] log
  * [x] general
  * [x] objects
  * [x] actors
  * [x] room
  * [x] textures
  * [x] threads
  * [x] sounds
* [x] cutscene
  * [x] cutscene UI (ESC)
  * [x] cutscene override
* [x] audio
  * [x] sound position
  * [x] talk
  * [x] sound
  * [x] music
* [x] triggers
  * [x] room trigger should be called in a thread (to be breakable)
  * [x] sound triggers
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
- [x] flashSelectableActor
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
- [x] stopSentence
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
- [x] roomEffect
  - [x] EFFECT_NONE
  - [x] EFFECT_SEPIA
  - [x] EFFECT_EGA
  - [x] EFFECT_VHS
  - [x] EFFECT_GHOST
  - [x] EFFECT_BLACKANDWHITE
- [x] roomFade
  - [x] FADE_IN
  - [x] FADE_OUT
  - [x] FADE_WOBBLE
  - [x] FADE_WOBBLE_TO_SEPIA
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
- [x] moveCursorTo
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
- [x] jiggleObject
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
- [x] popInventory
- [x] removeInventory
- [x] setDefaultObject
- [x] shakeObject
- [x] stopObjectMotors

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

import sqnim
import vm
import squtils
import syslib
import generallib
import roomlib
import objlib

# private methods

#public methods
proc register_gamelib*(v: HSQUIRRELVM) =
  v.register_generallib()
  v.register_objlib()
  v.register_roomlib()
  v.register_syslib()

proc register_gameconstants*(v: HSQUIRRELVM) =
  sqBind(v):
    const 
      ALL = 1
      HERE = 0
      GONE = 4
      OFF = 0
      ON = 1
      FULL = 0
      EMPTY = 1
      OPEN = 1
      CLOSED = 0
      FALSE = 0
      TRUE = 0
      MOUSE = 1
      CONTROLLER = 2
      DIRECTDRIVE = 3
      TOUCH = 4
      REMOTE = 5
      FADE_IN = 0
      FADE_OUT = 1
      FADE_WOBBLE = 2
      FADE_WOBBLE_TO_SEPIA = 3
      FACE_FRONT = 4
      FACE_BACK = 8
      FACE_LEFT = 2
      FACE_RIGHT = 1
      FACE_FLIP = 16
      DIR_FRONT = 4
      DIR_BACK = 8
      DIR_LEFT = 2
      DIR_RIGHT = 1
      LINEAR = 0
      EASE_IN = 1
      EASE_INOUT = 2
      EASE_OUT = 3
      SLOW_EASE_IN = 4
      SLOW_EASE_OUT = 5
      LOOPING = 0x100
      SWING = 0X200
      ALIGN_LEFT =   0x0000000010000000
      ALIGN_CENTER = 0x0000000020000000
      ALIGN_RIGHT =  0x0000000040000000
      ALIGN_TOP =    0xFFFFFFFF80000000
      ALIGN_BOTTOM = 0x0000000001000000
      LESS_SPACING = 0x0000000000200000
      EX_ALLOW_SAVEGAMES = 1
      EX_POP_CHARACTER_SELECTION = 2
      EX_CAMERA_TRACKING = 3
      EX_BUTTON_HOVER_SOUND = 4
      EX_RESTART = 6
      EX_IDLE_TIME = 7
      EX_AUTOSAVE = 8
      EX_AUTOSAVE_STATE = 9
      EX_DISABLE_SAVESYSTEM = 10
      EX_SHOW_OPTIONS = 11
      EX_OPTIONS_MUSIC = 12
      EX_FORCE_TALKIE_TEXT = 13
      GRASS_BACKANDFORTH = 0x00
      EFFECT_NONE = 0x00
      DOOR = 0x40
      DOOR_LEFT = 0x140
      DOOR_RIGHT = 0x240
      DOOR_BACK = 0x440
      DOOR_FRONT = 0x840
      FAR_LOOK = 0x8
      USE_WITH = 2
      USE_ON = 4
      USE_IN = 32
      GIVEABLE = 0x1000
      TALKABLE = 0x2000
      IMMEDIATE = 0x4000
      FEMALE = 0x80000
      MALE = 0x100000
      PERSON = 0x200000
      REACH_HIGH = 0x8000
      REACH_MED = 0x10000
      REACH_LOW = 0x20000
      REACH_NONE = 0x40000
      VERB_CLOSE = 6
      VERB_GIVE = 9
      VERB_LOOKAT = 2
      VERB_OPEN = 5
      VERB_PICKUP = 4
      VERB_PULL = 8
      VERB_PUSH = 7
      VERB_TALKTO = 3
      VERB_USE = 10
      VERB_WALKTO = 1
      VERB_DIALOG = 13
      VERBFLAG_INSTANT = 1
      NO = 0
      YES = 1
      UNSELECTABLE = 0
      SELECTABLE = 1
      TEMP_UNSELECTABLE = 2
      TEMP_SELECTABLE = 3
      MAC = 1
      WIN = 2
      LINUX = 3
      XBOX = 4
      IOS = 5
      ANDROID = 6
      SWITCH = 7
      PS4 = 8

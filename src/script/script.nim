import sqnim
import vm
import squtils
import syslib
import generallib
import roomlib
import objlib
import actorlib
import soundlib
import flags
import ../game/shaders

proc register_vars(v: HSQUIRRELVM) =
  var value: SQInteger
  case hostOS:
  of "macosx":
    value = 1
  of "windows":
    value = 2
  of "linux":
    value = 3
  else:
    # TODO:
    value = 3
  sq_pushstring(v, "PLATFORM", -1)
  sq_pushinteger(v, value)
  discard sq_newslot(v, -3, SQFalse)

#public methods
proc register_gamelib*(v: HSQUIRRELVM) =
  v.register_vars()
  v.register_generallib()
  v.register_objlib()
  v.register_roomlib()
  v.register_syslib()
  v.register_actorlib()
  v.register_sndlib()

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
      TRUE = 1
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
      LOOPING = 0x10
      SWING = 0X20
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
      GIVEABLE = GIVEABLE
      TALKABLE = TALKABLE
      IMMEDIATE = 0x4000
      FEMALE = 0x80000
      MALE = 0x100000
      PERSON = 0x200000
      REACH_HIGH = 0x8000
      REACH_MED = 0x10000
      REACH_LOW = 0x20000
      REACH_NONE = 0x40000
      VERB_WALKTO = 1
      VERB_LOOKAT = 2
      VERB_TALKTO = 3
      VERB_PICKUP = 4
      VERB_OPEN = 5
      VERB_CLOSE = 6
      VERB_PUSH = 7
      VERB_PULL = 8
      VERB_GIVE = 9
      VERB_USE = 10
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
      EFFECT_NONE           = RoomEffect.None.int
      EFFECT_SEPIA          = RoomEffect.Sepia.int
      EFFECT_EGA            = RoomEffect.Ega.int
      EFFECT_VHS            = RoomEffect.Vhs.int
      EFFECT_GHOST          = RoomEffect.Ghost.int
      EFFECT_BLACKANDWHITE  = RoomEffect.BlackAndWhite.int
      # these codes corresponds to SDL key codes used in TWP
      KEY_UP = 0x40000052
      KEY_RIGHT = 0x4000004F
      KEY_DOWN = 0x40000051
      KEY_LEFT = 0x40000050
      KEY_PAD1 = 0x40000059
      KEY_PAD2 = 0x4000005A
      KEY_PAD3 = 0x4000005B
      KEY_PAD4 = 0x4000005C
      KEY_PAD5 = 0x4000005D
      KEY_PAD6 = 0x4000005E
      KEY_PAD7 = 0x4000005F
      KEY_PAD8 = 0x40000056
      KEY_PAD9 = 0x40000061
      KEY_ESCAPE = 0x08
      KEY_TAB = 0x09
      KEY_RETURN = 0x0D
      KEY_BACKSPACE = 0x1B
      KEY_SPACE = 0X20
      KEY_A = 0x61
      KEY_B = 0x62
      KEY_C = 0x63
      KEY_D = 0x64
      KEY_E = 0x65
      KEY_F = 0x66
      KEY_G = 0x67
      KEY_H = 0x68
      KEY_I = 0x69
      KEY_J = 0x6A
      KEY_K = 0x6B
      KEY_L = 0x6C
      KEY_M = 0x6D
      KEY_N = 0x6E
      KEY_O = 0x6F
      KEY_P = 0x70
      KEY_Q = 0x71
      KEY_R = 0x72
      KEY_S = 0x73
      KEY_T = 0x74
      KEY_U = 0x75
      KEY_V = 0x76
      KEY_W = 0x77
      KEY_X = 0x78
      KEY_Y = 0x79
      KEY_Z = 0x7A
      KEY_0 = 0x30
      KEY_1 = 0x31
      KEY_2 = 0x32
      KEY_3 = 0x33
      KEY_4 = 0x34
      KEY_5 = 0x35
      KEY_6 = 0x36
      KEY_7 = 0x37
      KEY_8 = 0x38
      KEY_9 = 0x39
      KEY_F1 = 0x4000003A
      KEY_F2 = 0x4000003B
      KEY_F3 = 0x4000003C
      KEY_F4 = 0x4000003D
      KEY_F5 = 0x4000003E
      KEY_F6 = 0x4000003F
      KEY_F7 = 0x40000040
      KEY_F8 = 0x40000041
      KEY_F9 = 0x40000042
      KEY_F10 = 0x40000043
      KEY_F11 = 0x40000044
      KEY_F12 = 0x40000045

      BUTTON_A = 0x3E8
      BUTTON_B = 0x3E9
      BUTTON_X = 0x3EA
      BUTTON_Y = 0x3EB
      BUTTON_START = 0x3EC
      BUTTON_BACK = 0x3EC
      BUTTON_MOUSE_LEFT = 0x3ED
      BUTTON_MOUSE_RIGHT = 0x3EE

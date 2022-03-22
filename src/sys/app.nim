import glm
import sdl2
import ../sys/opengl
import ../gfx/graphics
import ../sys/input

# global variables
var w: WindowPtr
var glContext: GlContextPtr
var close = false
var appOnDrop: proc (paths: seq[string])
var appOnKey: proc (key: InputKey, scancode: int32, action: InputAction, mods: InputModifierKey)
var appOnMouseButton: proc(button: int32, action: InputAction)
var appOnMouseMove: proc(pos: Vec2f)

# public procedures
proc init*(title = "", size = vec2(1280, 720)) =
  sdl2.init(INIT_EVERYTHING)

  discard glSetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE)
  discard glSetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3)
  discard glSetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3)
  discard glSetAttribute(SDL_GL_DOUBLEBUFFER, 1)
  discard glSetAttribute(SDL_GL_DEPTH_SIZE, 24)
  discard glSetAttribute(SDL_GL_STENCIL_SIZE, 8)

  w = createWindow(title, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, size.x.int32, size.y.int32, SDL_WINDOW_ALLOW_HIGHDPI or SDL_WINDOW_OPENGL or SDL_WINDOW_SHOWN or SDL_WINDOW_RESIZABLE)
  if w == nil:
    w.destroyWindow()
    quit(-1)

  glContext = glCreateContext(w)

  discard glMakeCurrent(w, glContext)
  discard glSetSwapInterval(1)

  doAssert glInit()
  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

  gfxInit()

  var wi, he: cint
  glGetDrawableSize(w, wi, he)
  glViewport(0.GLint, 0.GLint, wi.GLsizei, he.GLsizei)

proc toInputKey(key: cint): InputKey =
  cast[InputKey](key)

proc toInputModifierKey(modifier: Keymod): InputModifierKey =
  case modifier:
  of KMOD_LSHIFT, KMOD_RSHIFT:
    Shift
  of KMOD_LCTRL, KMOD_RCTRL:
    Control
  of KMOD_LALT, KMOD_RALT:
    Alt
  of KMOD_LGUI, KMOD_RGUI:
    Super
  of KMOD_CAPS:
    CapsLock
  of KMOD_NUM:
    NumLock
  else:
    None

proc run*(render: proc()) =
  var e: Event
  while not close:
    if sdl2.pollEvent(e):
      case e.kind:
      of QuitEvent: close = true
      of KeyDown, KeyUp:
        if appOnKey != nil:
          let key = cast[KeyboardEventObj](e)
          appOnKey(toInputKey(key.keysym.sym), key.keysym.scancode.int32, if e.kind == KeyDown: iaPressed else: iaReleased, toInputModifierKey(key.keysym.modstate.KeyMod))
      of MouseButtonDown, MouseButtonUp:
        if appOnMouseButton != nil:
          let mouse = cast[MouseButtonEventObj](e)
          appOnMouseButton(mouse.button.int32, if e.kind == MouseButtonDown: iaPressed else: iaReleased)
      of MouseMotion:
        if appOnMouseMove != nil:
          let mouse = cast[MouseMotionEventObj](e)
          appOnMouseMove(vec2f(mouse.x.float32, mouse.y.float32))
      else: discard

    # render scene
    render()

    glSwapWindow(w)

  w.destroyWindow()
  sdl2.quit()

proc setDropCallback*(onDrop: proc (paths: seq[string])) =
  appOnDrop = onDrop

proc setMouseButtonCallback*(onMouseButton: proc(button: int32, action: InputAction)) =
  appOnMouseButton = onMouseButton

proc setMouseMoveCallback*(onMouseMove: proc(pos: Vec2f)) =
  appOnMouseMove = onMouseMove

proc setKeyCallback*(onKey: proc (key: InputKey, scancode: int32, action: InputAction, mods: InputModifierKey)) =
  appOnKey = onKey

proc getMousePosition*(): Vec2f =
  var xpos, ypos: cint
  getPosition(w, xpos, ypos)
  result = vec2(xpos.float32, ypos.float32)

proc appQuit*(quit = true) =
  close = quit

proc appGetWindowSize*(): Vec2i =
  var width, height: cint
  getSize(w, width, height)
  vec2(width, height)
import glm
import sdl2
import sdl2/mixer
import ../gfx/graphics
import ../gfx/texture
import ../game/screen
import ../sys/input
import ../libs/opengl
import ../libs/imgui
import ../libs/imgui/impl_sdl2
import ../libs/imgui/impl_opengl
# don't know why I need to include this, this is the only place where I can use igXXX methods
include debug

type
  MouseButtonFlag* = enum
    mbLeft    = 1,
    mbMiddle  = 2,
    mbRight   = 4
  MouseButtonMask* = set[MouseButtonFlag]

# global variables
var w: WindowPtr
var glContext: GlContextPtr
var gContext: ptr ImGuiContext
var close = false
var appOnDrop: proc (paths: seq[string])
var appOnKey: seq[proc (key: InputKey, scancode: int32, action: InputAction, mods: InputModifierKey)]
var appOnMouseButton: proc(button: int32, action: InputAction)
var appOnMouseMove: proc(pos: Vec2f)

# public procedures
proc init*(title = "", size = vec2(ScreenWidth, ScreenHeight)) =
  sdl2.init(INIT_EVERYTHING)
  discard mixer.openAudio(MIX_DEFAULT_FREQUENCY, MIX_DEFAULT_FORMAT, 2, 4096)
  discard mixer.allocateChannels(32)

  discard glSetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE)
  discard glSetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3)
  discard glSetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3)
  discard glSetAttribute(SDL_GL_DOUBLEBUFFER, 1)
  discard glSetAttribute(SDL_GL_DEPTH_SIZE, 24)
  discard glSetAttribute(SDL_GL_STENCIL_SIZE, 8)

  w = createWindow(title, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, size.x.int32, size.y.int32, SDL_WINDOW_ALLOW_HIGHDPI or SDL_WINDOW_OPENGL or SDL_WINDOW_SHOWN or SDL_WINDOW_RESIZABLE)
  if w == nil:
    w.destroyWindow()
    mixer.closeAudio()
    quit(-1)

  glContext = glCreateContext(w)

  discard glMakeCurrent(w, glContext)
  discard glSetSwapInterval(1)

  doAssert glInit()
  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

  gContext = igCreateContext()
  discard igSdl2InitForOpenGL(w)
  discard igOpenGL3Init()

  igStyleColorsDark()

  gfxInit()

  var wi, he: cint
  glGetDrawableSize(w, wi, he)
  glViewport(0.GLint, 0.GLint, wi.GLsizei, he.GLsizei)

proc getWinHandle*(): WindowPtr =
  w

proc setFullscreen*(state: bool) =
  discard w.setFullscreen(if state: 1'u32 else: 0'u32)

proc toInputKey(key: cint): InputKey =
  cast[InputKey](key)

proc toInputModifierKey(modifier: Keymod): InputModifierKey =
  if (modifier and KMOD_LSHIFT) == KMOD_LSHIFT  or (modifier and KMOD_RSHIFT) == KMOD_RSHIFT:
    result = (result.int32 or InputModifierKey.Shift.int32).InputModifierKey
  if (modifier and KMOD_LCTRL) == KMOD_LCTRL or (modifier and KMOD_RCTRL) == KMOD_RCTRL:
    result = (result.int32 or InputModifierKey.Control.int32).InputModifierKey
  if (modifier and KMOD_LALT) == KMOD_LALT or (modifier and KMOD_RALT) == KMOD_RALT:
    result = (result.int32 or InputModifierKey.Alt.int32).InputModifierKey
  if (modifier and KMOD_LGUI) == KMOD_LGUI or (modifier and KMOD_RGUI) == KMOD_RGUI:
    result = (result.int32 or InputModifierKey.Super.int32).InputModifierKey
  if (modifier and KMOD_CAPS) == KMOD_CAPS:
    result = (result.int32 or InputModifierKey.CapsLock.int32).InputModifierKey
  if (modifier and KMOD_NUM) == KMOD_CAPS:
    result = (result.int32 or InputModifierKey.NumLock.int32).InputModifierKey

proc run*(render: proc()) =
  var e: Event
  while not close:
    while sdl2.pollEvent(e):
      case e.kind:
      of QuitEvent: close = true
      of KeyDown, KeyUp:
        for handler in appOnKey:
          let key = cast[KeyboardEventObj](e)
          handler(toInputKey(key.keysym.sym), key.keysym.scancode.int32, if e.kind == KeyDown: iaPressed else: iaReleased, toInputModifierKey(key.keysym.modstate.KeyMod))
      of MouseButtonDown, MouseButtonUp:
        if appOnMouseButton != nil:
          let mouse = cast[MouseButtonEventObj](e)
          appOnMouseButton(mouse.button.int32, if e.kind == MouseButtonDown: iaPressed else: iaReleased)
      of MouseMotion:
        if appOnMouseMove != nil:
          let mouse = cast[MouseMotionEventObj](e)
          appOnMouseMove(vec2f(mouse.x.float32, mouse.y.float32))
      else: discard

      discard igSdl2ProcessEvent(e)

    # render scene
    igOpenGL3NewFrame()
    igSdl2NewFrame()
    igNewFrame()

    imguiRender()
    render()

    igRender()
    igOpenGL3RenderDrawData(igGetDrawData())

    glSwapWindow(w)

  igOpenGL3Shutdown()
  igSdl2Shutdown()
  igDestroyContext(gContext)

  w.destroyWindow()
  mixer.closeAudio()
  sdl2.quit()

proc setDropCallback*(onDrop: proc (paths: seq[string])) =
  appOnDrop = onDrop

proc setMouseButtonCallback*(onMouseButton: proc(button: int32, action: InputAction)) =
  appOnMouseButton = onMouseButton

proc setMouseMoveCallback*(onMouseMove: proc(pos: Vec2f)) =
  appOnMouseMove = onMouseMove

proc setKeyCallback*(onKey: proc (key: InputKey, scancode: int32, action: InputAction, mods: InputModifierKey)) =
  appOnKey.add onKey

proc mousePos*(): Vec2f =
  var xpos, ypos: cint
  discard getMouseState(xpos, ypos)
  result = vec2(xpos.float32, ypos.float32)

proc mouseMove*(pos: Vec2i) =
  warpMouseInWindow(w, pos.x.cint, pos.y.cint)

proc mouseBtns*(): MouseButtonMask =
  var xpos, ypos: cint
  let state = getMouseState(xpos, ypos)
  result = {}
  let io = igGetIO()
  if not io.wantCaptureMouse:
    if (state and BUTTON_LMASK) != 0:
      result.incl mbLeft
    if (state and BUTTON_MMASK) != 0:
      result.incl mbMiddle
    if (state and BUTTON_RMASK) != 0:
      result.incl mbRight

proc appQuit*(quit = true) =
  close = quit

proc appGetWindowSize*(): Vec2i =
  var width, height: cint
  getSize(w, width, height)
  vec2(width.int32, height.int32)

proc appSetRenderTarget*(self: RenderTexture = nil) =
  if self.isNil:
    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    var wi, he: cint
    glGetDrawableSize(getWinHandle(), wi, he)
    glViewport(0.GLint, 0.GLint, wi, he)
  else:
    glBindFramebuffer(GL_FRAMEBUFFER, self.fbo)
    glViewport(0.GLint, 0.GLint, self.size.x, self.size.y)

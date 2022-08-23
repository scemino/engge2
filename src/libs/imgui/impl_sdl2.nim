import sdl2
import ../imgui

{.push warning[user]: off}
when defined(windows):
  const LibName* = "SDL2.dll"
elif defined(macosx):
  const LibName* = "libSDL2.dylib"
elif defined(openbsd):
  const LibName* = "libSDL2.so.0.6"
else:
  const LibName* = "libSDL2.so"
{.pop.}

{.push callConv: cdecl, dynlib: LibName.}
proc getGlobalMouseState*(x, y: var cint): uint32 {.importc: "SDL_GetGlobalMouseState", discardable.}
{.pop.}

var
  gWindow: WindowPtr
  gFrequency: uint64
  gTime: uint64
  gMousePressed: array[3, bool]
  gClipboardTextData: cstring
  gMouseCursors: array[9, CursorPtr]
  gMouseCanUseGlobalState: bool

proc igSdl2GetClipboardText(userData: pointer): constChar {.cdecl.} =
  if not gClipboardTextData.isNil:
    freeClipboardText(gClipboardTextData)
  gClipboardTextData = getClipboardText()
  return cast[constChar](gClipboardTextData)

proc igSdl2SetClipboardText(userData: pointer, text: constChar): void {.cdecl.} =
  discard setClipboardText(cast[cstring](text))

proc igSdl2Init(window: WindowPtr): bool =
  gTime = 0
  gWindow = window
  gFrequency = getPerformanceFrequency()

  let io = igGetIO()

  # Check and store if we are on a SDL backend that supports global mouse position
  # ("wayland" and "rpi" don't support it, but we chose to use a white-list instead of a black-list)
  let sdl_backend = $getCurrentVideoDriver()
  gMouseCanUseGlobalState = sdl_backend in ["windows", "cocoa", "x11", "DIVE", "VMAN"]

  io.backendPlatformName = "imgui_impl_sdl".cstring
  io.backendFlags = (io.backendFlags.int32 or ImGuiBackendFlags.HasMouseCursors.int32).ImGuiBackendFlags
  io.backendFlags = (io.backendFlags.int32 or ImGuiBackendFlags.HasSetMousePos.int32).ImGuiBackendFlags

  # Keyboard mapping. Dear ImGui will use those indices to peek into the io.KeysDown[] array.
  io.keyMap[ImGuiKey.Tab.int32] = SDL_SCANCODE_TAB.int32
  io.keyMap[ImGuiKey.LeftArrow.int32] = SDL_SCANCODE_LEFT.int32
  io.keyMap[ImGuiKey.RightArrow.int32] = SDL_SCANCODE_RIGHT.int32
  io.keyMap[ImGuiKey.UpArrow.int32] = SDL_SCANCODE_UP.int32
  io.keyMap[ImGuiKey.DownArrow.int32] = SDL_SCANCODE_DOWN.int32
  io.keyMap[ImGuiKey.PageUp.int32] = SDL_SCANCODE_PAGEUP.int32
  io.keyMap[ImGuiKey.PageDown.int32] = SDL_SCANCODE_PAGEDOWN.int32
  io.keyMap[ImGuiKey.Home.int32] = SDL_SCANCODE_HOME.int32
  io.keyMap[ImGuiKey.End.int32] = SDL_SCANCODE_END.int32
  io.keyMap[ImGuiKey.Insert.int32] = SDL_SCANCODE_INSERT.int32
  io.keyMap[ImGuiKey.Delete.int32] = SDL_SCANCODE_DELETE.int32
  io.keyMap[ImGuiKey.Backspace.int32] = SDL_SCANCODE_BACKSPACE.int32
  io.keyMap[ImGuiKey.Space.int32] = SDL_SCANCODE_SPACE.int32
  io.keyMap[ImGuiKey.Enter.int32] = SDL_SCANCODE_RETURN.int32
  io.keyMap[ImGuiKey.Escape.int32] = SDL_SCANCODE_ESCAPE.int32
  io.keyMap[ImGuiKey.KeyPadEnter.int32] = SDL_SCANCODE_KP_ENTER.int32
  io.keyMap[ImGuiKey.A.int32] = SDL_SCANCODE_A.int32
  io.keyMap[ImGuiKey.C.int32] = SDL_SCANCODE_C.int32
  io.keyMap[ImGuiKey.V.int32] = SDL_SCANCODE_V.int32
  io.keyMap[ImGuiKey.X.int32] = SDL_SCANCODE_X.int32
  io.keyMap[ImGuiKey.Y.int32] = SDL_SCANCODE_Y.int32
  io.keyMap[ImGuiKey.Z.int32] = SDL_SCANCODE_Z.int32

  io.setClipboardTextFn = igSdl2SetClipboardText
  io.getClipboardTextFn = igSdl2GetClipboardText

  # Load mouse cursors
  gMouseCursors[ImGuiMouseCursor.Arrow.int] = createSystemCursor(SDL_SYSTEM_CURSOR_ARROW)
  gMouseCursors[ImGuiMouseCursor.TextInput.int] = createSystemCursor(SDL_SYSTEM_CURSOR_IBEAM)
  gMouseCursors[ImGuiMouseCursor.ResizeAll.int] = createSystemCursor(SDL_SYSTEM_CURSOR_SIZEALL)
  gMouseCursors[ImGuiMouseCursor.ResizeNS.int] = createSystemCursor(SDL_SYSTEM_CURSOR_SIZENS)
  gMouseCursors[ImGuiMouseCursor.ResizeEW.int] = createSystemCursor(SDL_SYSTEM_CURSOR_SIZEWE)
  gMouseCursors[ImGuiMouseCursor.ResizeNESW.int] = createSystemCursor(SDL_SYSTEM_CURSOR_SIZENESW)
  gMouseCursors[ImGuiMouseCursor.ResizeNWSE.int] = createSystemCursor(SDL_SYSTEM_CURSOR_SIZENWSE)
  gMouseCursors[ImGuiMouseCursor.Hand.int] = createSystemCursor(SDL_SYSTEM_CURSOR_HAND)
  gMouseCursors[ImGuiMouseCursor.NotAllowed.int] = createSystemCursor(SDL_SYSTEM_CURSOR_NO)

  return true

proc igSdl2InitForOpenGL*(window: WindowPtr): bool =
  igSdl2Init(window)

proc igSdl2ProcessEvent*(event: Event): bool =
  let io = igGetIO()

  case event.kind:
  of MouseWheel:
    let mouseWheel = cast[MouseWheelEventObj](event)
    if mouseWheel.x > 0: io.mouseWheelH += 1
    if mouseWheel.x < 0: io.mouseWheelH -= 1
    if mouseWheel.y > 0: io.mouseWheel += 1
    if mouseWheel.y < 0: io.mouseWheel -= 1
    return true
  of MouseButtonDown:
    if event.button.button == BUTTON_LEFT:   gMousePressed[0] = true
    if event.button.button == BUTTON_RIGHT:  gMousePressed[1] = true
    if event.button.button == BUTTON_MIDDLE: gMousePressed[2] = true
    return true
  of TextInput:
    io.addInputCharactersUTF8(cast[cstring](event.text.text[0].unsafeAddr))
    return true
  of KeyDown, KeyUp:
    var key = event.key.keysym.scancode
    io.keysDown[key.int] = (event.kind == KeyDown)
    io.keyShift = ((getModState() and KMOD_SHIFT) != 0)
    io.keyCtrl = ((getModState() and KMOD_CTRL) != 0)
    io.keyAlt = ((getModState() and KMOD_ALT) != 0)
    when defined windows:
      io.keySuper = false
    when not defined windows:
      io.keySuper = (getModState() and KMOD_GUI) != 0
    return true
  of WindowEvent:
    if event.window.event == WindowEvent_FocusGained:
      io.addFocusEvent(true)
    elif event.window.event == WindowEvent_FocusLost:
      io.addFocusEvent(false)
    return true
  else:
    return false

proc igSdl2UpdateMousePosAndButtons() =
  let io = igGetIO()
  
  var mouse_pos_prev = io.mousePos
  io.mousePos = ImVec2(x: -float32.high, y: -float32.high)

  # Update mouse buttons
  var mouse_x_local, mouse_y_local: cint
  let mouse_buttons = getMouseState(mouse_x_local, mouse_y_local)
  io.mouseDown[0] = gMousePressed[0] or (mouse_buttons and SDL_BUTTON(BUTTON_LEFT)) != 0  # If a mouse press event came, always pass it as "mouse held this frame", so we don't miss click-release events that are shorter than 1 frame.
  io.mouseDown[1] = gMousePressed[1] or (mouse_buttons and SDL_BUTTON(BUTTON_RIGHT)) != 0
  io.mouseDown[2] = gMousePressed[2] or (mouse_buttons and SDL_BUTTON(BUTTON_MIDDLE)) != 0
  gMousePressed[0] = false
  gMousePressed[1] = false
  gMousePressed[2] = false

  # SDL 2.0.3 and non-windowed systems: single-viewport only
  let mouse_window = if (getFlags(gWindow) and SDL_WINDOW_INPUT_FOCUS) != 0: gWindow else: nil
  if mouse_window.isNil:
    return

  # Set OS mouse position from Dear ImGui if requested (rarely used, only when ImGuiConfigFlags_NavEnableSetMousePos is enabled by user)
  if io.wantSetMousePos:
    var mousePrevX, mousePrevY: cint
    warpMouseInWindow(gWindow, mousePrevX, mousePrevY)
    mouse_pos_prev = ImVec2(x: mousePrevX.float32, y: mousePrevY.float32)

  # Set Dear ImGui mouse position from OS position + get buttons. (this is the common behavior)
  if gMouseCanUseGlobalState:
    # Single-viewport mode: mouse position in client window coordinates (io.MousePos is (0,0) when the mouse is on the upper-left corner of the app window)
    # Unlike local position obtained earlier this will be valid when straying out of bounds.
    var mouse_x_global, mouse_y_global: cint
    getGlobalMouseState(mouse_x_global, mouse_y_global)
    var window_x, window_y: cint
    getPosition(mouse_window, window_x, window_y)
    io.mousePos = ImVec2(x: (mouse_x_global - window_x).float32, y: (mouse_y_global - window_y).float32)
  else:
    io.mousePos = ImVec2(x: mouse_x_local.float32, y: mouse_y_local.float32)

proc igSdl2UpdateMouseCursor() =
  let io = igGetIO()
  if (io.configFlags.cint and ImGuiConfigFlags.NoMouseCursorChange.cint) != 0:
      return

  let imgui_cursor = igGetMouseCursor()
  if io.mouseDrawCursor or imgui_cursor == ImGuiMouseCursor.None:
    # Hide OS mouse cursor if imgui is drawing it or if it wants no cursor
    showCursor(false)
  else:
    # Show OS mouse cursor
    setCursor(if not gMouseCursors[imgui_cursor.int].isNil: gMouseCursors[imgui_cursor.int] else: gMouseCursors[ImGuiMouseCursor.Arrow.int])
    showCursor(true)

proc igSdl2NewFrame*() =
  let io = igGetIO()

  # Setup display size (every frame to accommodate for window resizing)
  var w, h: cint
  var display_w, display_h: cint
  getSize(gWindow, w, h)
  if (getFlags(gWindow) and SDL_WINDOW_MINIMIZED) != 0:
    w = 0.cint
    h = 0.cint
  glGetDrawableSize(gWindow, display_w, display_h)
  io.displaySize = ImVec2(x: w.float32, y: h.float32)
  if w > 0 and h > 0:
    io.displayFramebufferScale = ImVec2(x: display_w.float32 / w.float32, y: display_h.float32 / h.float32)

  # Setup time step (we don't use SDL_GetTicks() because it is using millisecond resolution)
  let current_time = getPerformanceCounter()
  io.deltaTime = if gTime > 0: (current_time - gTime).float32 / gFrequency.float32 else: 1.0'f32 / 60.0'f32
  gTime = current_time

  igSdl2UpdateMousePosAndButtons()
  igSdl2UpdateMouseCursor()

  # TOD/ Update game controllers (if enabled and available)
  #ImGui_ImplSDL2_UpdateGamepads()

proc igSdl2Shutdown*() =
  if not gClipboardTextData.isNil:
      freeClipboardText(gClipboardTextData)
  for n in 0..<gMouseCursors.len:
      freeCursor(gMouseCursors[n])

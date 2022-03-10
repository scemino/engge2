import std/logging
import sys/app
import gfx/graphics
import gfx/color
import sys/input
import glm

proc render() =
  gfxClear(Yellow)

proc onKey(key: InputKey, scancode: int32, action: InputAction, mods: InputModifierKey) = 
  echo key, scancode, action, mods

proc onMouseButton(button: int32, action: InputAction) = 
  echo button, action

proc onMouseMove(pos: Vec2f) = 
  echo pos

proc main() =
  addHandler(newConsoleLogger())
  addHandler(newFileLogger("log.txt"))
  info("# Welcome to ngnim")
  app.init(title = "ngnim")
  app.setKeyCallback(onKey)
  app.setMouseButtonCallback(onMouseButton)
  app.setMouseMoveCallback(onMouseMove)
  app.run(render)

main()

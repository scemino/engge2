# Package

version       = "0.1.0"
author        = "scemino"
description   = "An adventure game engine in nim"
license       = "MIT"
srcDir        = "src"
bin           = @["ngnim"]

# Dependencies

requires "nim >= 1.6.2"
requires "sdl2 >= 0.3.0"
requires "glm >= 1.1.1"
requires "stb_image >= 2.5.0"
requires "nimyggpack >= 0.1.0"
requires "sqnim >= 0.1.0"

backend = "cpp"

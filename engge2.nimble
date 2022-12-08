# Package

version       = "2.1.0"
author        = "scemino"
description   = "An adventure game engine in nim"
license       = "MIT"
srcDir        = "src"
bin           = @["engge2"]

# Dependencies

requires "nim >= 1.6.2"
requires "sdl2 >= 0.3.0"
requires "glm >= 1.1.1"
requires "https://github.com/scemino/stb_image >= 2.6.0"
requires "https://github.com/scemino/nimyggpack >= 0.4.0"
requires "https://github.com/scemino/sqnim >= 0.3.0"
requires "https://github.com/scemino/clipper >= 0.2.0"

backend = "cpp"

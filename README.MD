# engge 2

[![CI](https://github.com/scemino/engge2/actions/workflows/main.yml/badge.svg)](https://github.com/scemino/engge2/actions/workflows/main.yml)
[![Twitter URL](https://img.shields.io/twitter/url?style=social&url=https%3A%2F%2Ftwitter.com%2Fengge_the_game)](https://twitter.com/engge_the_game)

engge2 is an adventure game engine able to run Thimbleweed Park.

It's an open source remake of Thimbleweed Park's engine.

It's still a project in active development, and there are a lot of issues, don't hesitate to contribute or to fill out a [bug report](https://github.com/scemino/engge2/issues/new/choose).

![https://i.imgur.com/M13pC7M.png](https://i.imgur.com/M13pC7M.png)

## How to play

* Buy [Thimbleweed park](https://thimbleweedpark.com)
* Go to your installation folder and copy these files:  `ThimbleweedPark.ggpack1` and `ThimbleweedPark.ggpack2` to `engge2` directory
* You can also copy your savegames from Thimbleweed Park: `Savegame*.save` and `Savegame*.png`
* You can even keep your achievements by copying the Save.dat file
* Ready ? Just type `./engge2`

## How to build

* Clone the repository: `git clone https://github.com/scemino/engge2.git`
* Initialize submodules: `git submodule update --init --recursive`
* Build and run: `nimble run`

## Dependencies

  * [sdl2](https://www.libsdl.org/): Simple DirectMedia Layer is a cross-platform development library designed to provide low level access to audio, keyboard, mouse, joystick, and graphics hardware via OpenGL and Direct3D.
  * [squirrel](http://www.squirrel-lang.org/): programming language Squirrel, this repository contains a modified version of the official squirrel library in *extlibs/squirrel*
  * [clipper](http://www.angusj.com/clipper2/Docs/Overview.htm): Polygon Clipping and Offsetting Library
  * [glm](https://github.com/g-truc/glm): (GLM) is a header only C++ mathematics library for graphics software based on the OpenGL Shading Language (GLSL) specifications.
  * [stb_image](https://github.com/nothings/stb): from stb, single-file public domain (or MIT licensed) libraries for C/C++



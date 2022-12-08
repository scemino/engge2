# engge 2

[![CI](https://github.com/scemino/engge2/actions/workflows/main.yml/badge.svg)](https://github.com/scemino/engge2/actions/workflows/main.yml)
[![Twitter URL](https://img.shields.io/twitter/url?style=social&url=https%3A%2F%2Ftwitter.com%2Fengge_the_game)](https://twitter.com/engge_the_game)
[![Discord URL](https://img.shields.io/discord/701169824495042591)](https://discordapp.com/channels/701169824495042591)

`engge2` is an adventure game engine able to run `Thimbleweed Park`.

It's an open source remake of `Thimbleweed Park`'s engine.

It's still a project in active development, and there are a lot of issues, don't hesitate to contribute or to fill out a [bug report](https://github.com/scemino/engge2/issues/new/choose).

![https://i.imgur.com/M13pC7M.png](https://i.imgur.com/M13pC7M.png)

## How to play

* Buy [Thimbleweed park](https://thimbleweedpark.com)
* Go to your installation folder and copy these files:  `ThimbleweedPark.ggpack1` and `ThimbleweedPark.ggpack2` to `engge2` directory
* You can also copy your savegames from `Thimbleweed Park`: `Savegame*.save` and `Savegame*.png` (:warning: don't move your files, make a copy)
* You can even keep your achievements by copying the `Save.dat` file
* Ready ? Just type `./engge2`

## Ransome unbeeped DLC, Italian voice over and more

`engge 2` now supports [Ransome unbeeped](https://www.gog.com/game/thimbleweed_park_ransome_unbeeped) and also [Italian voiceover](https://www.gugames.eu/twp_voice.html).

Go to your installation folder and copy these files:  `ThimbleweedPark.ggpack3` to `engge2` directory.

You can even create your own `ggpack` and override the original assets à la [Doom WAD](https://en.wikipedia.org/wiki/Doom_modding) :wink: 

Rename your `ggpack` `ThimbleweedPark.ggpack3` or `ThimbleweedPark.ggpack4` or `ThimbleweedPark.ggpack5` or ... you get it now :smile:.

## The game says "This is NOT a valid ggpack file"

If it happens, create a file and named it `Prefs.json` and write this content:

```json
{
  "key": "56ad"
}
```

The key value can be one of these values: `"56ad"`, `"566d"`, `"5b6d"`, `"5bad"`.

If it still doesn't work, try another key from above.

## You found a bug or have questions

If you found a bug or something is annoying, don't give up! and please fill out a [bug report](https://github.com/scemino/engge2/issues/new/choose).

You have 1 question or more, don't hesitate, [ask](https://github.com/scemino/engge2/issues/new/choose).

## How to build

* Clone the repository: `git clone https://github.com/scemino/engge2.git`
* Initialize submodules: `git submodule update --init --recursive`
* Build and run: `nimble run`

## Why engge 2 ?

* [engge](https://github.com/scemino/engge) was a C++ project, during the development I was frustrated by C++, I decided to fix the last bugs by starting from scratch and experimenting a new language: [nim](https://nim-lang.org/)

## Thanks

Thanks to the authors of these projects which help me to accomplish this project:

* [sdl2](https://www.libsdl.org/): Simple DirectMedia Layer is a cross-platform development library designed to provide low level access to audio, keyboard, mouse, joystick, and graphics hardware via OpenGL and Direct3D.
* [Dear ImGui](https://github.com/ocornut/imgui): Bloat-free Graphical User interface for C++ with minimal dependencies
* [stb_image](https://github.com/nothings/stb): from stb, single-file public domain (or MIT licensed) libraries for C/C++
* [nimgl](https://github.com/nimgl/nimgl): Nim Game Library,
a collection of bindings for popular libraries, mostly used in computer graphics
* [squirrel](http://www.squirrel-lang.org/): programming language Squirrel, this repository contains a modified version of the official squirrel library in *extlibs/squirrel*
* [clipper](http://www.angusj.com/clipper2/Docs/Overview.htm): Polygon Clipping and Offsetting Library
* [glm](https://github.com/g-truc/glm): (GLM) is a header only C++ mathematics library for graphics software based on the OpenGL Shading Language (GLSL) specifications.

And many thanks to the people how helped me with [engge](https://github.com/.scemino/engge).
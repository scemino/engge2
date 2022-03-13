import std/[random, sharedlist, streams, tables, logging]
import sqnim
import ../gfx/spritesheet
import ../gfx/texture
import ../gfx/graphics
import ../gfx/image
import ../gfx/recti
import ../gfx/color
import ../io/ggpackmanager
import room
import functions

type Engine* = ref object of RootObj
  rand*: Rand
  spriteSheets: Table[string, SpriteSheet]
  textures: Table[string, Texture]
  objects*: seq[Object]
  funcs*: SharedList[BreakTimeFunction]

var gEngine*: Engine

proc newEngine*(): Engine =
  new(result)
  gEngine = result
  result.rand = initRand()
  result.funcs.init()

proc createObject*(self: Engine, v: HSQUIRRELVM, sheet: string, anims: seq[string]): HSQOBJECT =
  let content = gGGPackMgr.loadStream(sheet & ".json").readAll
  if not self.spriteSheets.contains(sheet):
    info "load SpriteSheet: " & sheet
    self.spriteSheets[sheet] = parseSpriteSheet(content)
    info "load texture: " & self.spriteSheets[sheet].meta.image
    self.textures[sheet] = newTexture(newImage(self.spriteSheets[sheet].meta.image))

  info "createObject(" & sheet & "," & $anims & ")"
  sq_resetobject(result)
  sq_newtable(v)
  discard sq_getstackobj(v, -1, result)
  sq_addref(v, result)
  sq_pop(v, 1)
  self.objects.add(Object(sheet: sheet, anims: anims, obj: result))

proc update(self: Engine) =
  self.funcs.iterAndMutate(proc (f: BreakTimeFunction): bool = f.update(1/120))

proc render*(self: Engine) =
  self.update()
  
  camera(320, 180)
  gfxClear(Gray)
  for obj in self.objects:
    let frame = self.spriteSheets[obj.sheet].frames.getFrame(obj.anims[0])
    let size = self.spriteSheets[obj.sheet].meta.size
    gfxDrawSprite(obj.pos, rectf(frame.frame/size), self.textures[obj.sheet])


import std/[random, streams, tables, strutils, sequtils]
import sqnim
import glm
import ../gfx/spritesheet
import ../gfx/texture
import ../gfx/graphics
import ../gfx/color
import ../io/ggpackmanager
import room
import thread
import squtils
import ../util/tween

type Engine* = ref object of RootObj
  rand*: Rand
  spriteSheets: Table[string, SpriteSheet]
  textures: Table[string, Texture]
  v: HSQUIRRELVM
  roomTable: HSQOBJECT
  room*: Room
  background: string
  fade*: Tween[float]

var gEngine*: Engine

proc newEngine*(v: HSQUIRRELVM): Engine =
  new(result)
  gEngine = result
  result.rand = initRand()
  result.v = v
  sq_resetobject(result.roomTable)

proc loadRoom(entry: string): Room =
  let content = gGGPackMgr.loadStream(entry).readAll
  parseRoom(content)

proc setRoom*(self: Engine, roomTable: HSQOBJECT) =
  self.roomTable = roomTable
  self.v.getf(self.roomTable, "background", self.background)
  self.room = loadRoom(self.background & ".wimpy")
  for obj in self.room.objects:
    var oTbl: HSQOBJECT
    sq_resetobject(oTbl)
    getf(self.v, roomTable, obj.name, oTbl)
    if oTbl.objType == OT_NULL:
      sq_newtable(self.v)
      discard sq_getstackobj(self.v, -1, oTbl)
      sq_addref(self.v, oTbl)
      sq_pop(self.v, 1)

      sq_pushobject(self.v, oTbl)
      sq_pushstring(self.v, "name", -1)
      sq_pushstring(self.v, obj.name, -1)
      discard sq_newslot(self.v, -3, false)
      
      sq_pushobject(self.v, roomTable)
      sq_pushstring(self.v, obj.name, -1)
      sq_pushobject(self.v, oTbl)
      discard sq_newslot(self.v, -3, false)
      sq_pop(self.v, 1)

  call(self.v, self.roomTable, "enter")

proc update(self: Engine) =
  var elapsed = 1/60
  for thread in gThreads.toSeq:
    if thread.update(elapsed):
      gThreads.del gThreads.find(thread)
  self.fade.update(elapsed)
  self.room.update(elapsed)
  
proc render*(self: Engine) =
  self.update()
  
  gfxClear(Gray)
  self.room.render()
  
  gfxDrawQuad(vec2f(0), vec2f(self.room.roomSize), rgbf(Black, self.fade.current()))

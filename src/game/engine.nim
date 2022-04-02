import std/[random, streams, tables, sequtils, strformat, logging]
import sqnim
import glm
import room
import actor
import thread
import squtils
import callback
import vm
import ids
import task
import ../gfx/spritesheet
import ../gfx/texture
import ../gfx/graphics
import ../gfx/color
import ../gfx/fntfont
import ../gfx/text
import ../io/ggpackmanager
import ../util/tween

type Engine* = ref object of RootObj
  rand*: Rand
  spriteSheets: Table[string, SpriteSheet]
  textures: Table[string, Texture]
  v: HSQUIRRELVM
  rooms*: seq[Room]
  actors*: seq[Actor]
  room*: Room
  background: string
  fade*: Tween[float]
  callbacks*: seq[Callback]
  tasks*: seq[Task]
  time*: float # time in seconds
  font: FntFont
  text: Text

var gEngine*: Engine
var gRoomId = START_ROOMID

proc newEngine*(v: HSQUIRRELVM): Engine =
  new(result)
  gEngine = result
  result.rand = initRand()
  result.v = v
  result.font = parseFntFont("/Users/scemino/CLionProjects/resources/TinyFont.fnt")
  result.text = newText(result.font)
  result.text.maxWidth = 160'f32
  result.text.text = "Thimbleweed #ff0080Park #008000is #0020FFan #0020FFawesome #10608Fadventure #8020FFgame"
  result.text.color = White
  result.text.update()

proc loadRoom*(name: string): Room =
  echo "room background: " & name
  let content = gGGPackMgr.loadStream(name & ".wimpy").readAll
  result = parseRoom(content)
  getf(gVm.v, gVm.v.rootTbl(), name, result.table)
  result.table.setId(gRoomId)
  gRoomId += 1
  for obj in result.objects:
    sq_resetobject(obj.table)
    getf(gVm.v, result.table, obj.name, obj.table)
    # check if the object exists in Squirrel VM
    if obj.table.objType == OT_NULL:
      info fmt"create table for obj: {obj.name}"
      # this object does not exist, so create it
      sq_newtable(gVm.v)
      discard sq_getstackobj(gVm.v, -1, obj.table)
      sq_addref(gVm.v, obj.table)
      sq_pop(gVm.v, 1)

      # assign a name
      sq_pushobject(gVm.v, obj.table)
      sq_pushstring(gVm.v, "name", -1)
      sq_pushstring(gVm.v, obj.name, -1)
      discard sq_newslot(gVm.v, -3, false)
      
      # adds the object to the room table
      sq_pushobject(gVm.v, result.table)
      sq_pushstring(gVm.v, obj.name, -1)
      sq_pushobject(gVm.v, obj.table)
      discard sq_newslot(gVm.v, -3, false)
      sq_pop(gVm.v, 1)
    else:
      echo "obj.name: " & obj.name

proc setRoom*(self: Engine, room: Room) =
  if self.room != room:
    self.fade.enabled = false
    self.room = room
    call(self.v, self.room.table, "enter")

proc update(self: Engine) =
  var elapsed = 1/60
  self.time += elapsed
  for thread in gThreads.toSeq:
    if thread.update(elapsed):
      #info fmt"thread {thread.name} is dead"
      gThreads.del gThreads.find(thread)
  for cb in self.callbacks.toSeq:
    if cb.update(elapsed):
      self.callbacks.del self.callbacks.find(cb)
  for t in self.tasks:
    #info("updating task: " & t.name)
    if t.update(elapsed):
      #info("delete task: " & t.name)
      self.tasks.del self.tasks.find(t)
      #info("task updated")
      break
    #info("task updated")
  self.fade.update(elapsed)
  if not self.room.isNil:
    self.room.update(elapsed)
  
proc render*(self: Engine) =
  self.update()
  
  gfxClear(Gray)
  if not self.room.isNil:
    self.room.render()
    let fade = if self.fade.enabled: self.fade.current() else: 0.0
    gfxDrawQuad(vec2f(0), vec2f(self.room.roomSize), rgbf(Black, fade))
    gfxDrawQuad(vec2f(0), vec2f(self.room.roomSize), self.room.overlay)

  for actor in self.actors:
    actor.draw()
  self.text.draw(rotate(translate(mat4(1.0'f32), vec3(20.0'f32, 100.0'f32, 0.0'f32)), 1.0, 0.0, 0.0, 1.0))
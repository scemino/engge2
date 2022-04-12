import std/[random, streams, tables, sequtils, strformat, logging]
import sqnim
import glm
import room
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
import ../io/ggpackmanager
import ../util/easing
import ../util/tween
import ../audio/audio
import ../scenegraph/node
import ../scenegraph/spritenode
import ../scenegraph/parallaxnode
import ../scenegraph/scene
import noderotateto

type Engine* = ref object of RootObj
  rand*: Rand
  spriteSheets: Table[string, SpriteSheet]
  textures: Table[string, Texture]
  v: HSQUIRRELVM
  rooms*: seq[Room]
  actors*: seq[Object]
  room*: Room
  fade*: Tween[float]
  callbacks*: seq[Callback]
  tasks*: seq[Task]
  threads*: seq[Thread]
  time*: float # time in seconds
  audio*: AudioSystem
  scene*: Scene

var gEngine*: Engine
var gRoomId = START_ROOMID

proc newEngine*(v: HSQUIRRELVM): Engine =
  new(result)
  gEngine = result
  result.rand = initRand()
  result.v = v
  result.audio = newAudioSystem()
  result.scene = newScene()

proc loadRoom*(name: string): Room =
  echo "room background: " & name
  let content = gGGPackMgr.loadStream(name & ".wimpy").readAll
  result = parseRoom(content)
  getf(gVm.v, gVm.v.rootTbl(), name, result.table)
  result.table.setId(gRoomId)
  gRoomId += 1
  for layer in result.layers:
    for obj in layer.objects:
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

proc getObj(room: Room, name: string): Object =
  for layer in room.layers:
      for obj in layer.objects:
        if obj.name == name:
          return obj

proc setRoom*(self: Engine, room: Room) =
  if self.room != room:
    self.fade.enabled = false
    self.room = room
    call(self.v, self.room.table, "enter")
    self.scene.removeAll()

    # create layer nodes
    for layer in self.room.layers:
      var frames: seq[SpriteSheetFrame]
      for name in layer.names:
        frames.add(room.spriteSheet.frames[name])
      var layerNode = newParallaxNode(room.texture, frames)
      layerNode.zOrder = layer.zSort
      self.scene.addChild layerNode

      for obj in layer.objects:
        if obj.anims.len > 0:
          var ss = obj.getSpriteSheet()
          var frame = ss.frames[obj.anims[0].frames[0]]
          var spNode = newSpriteNode(obj.getTexture(), frame)
          spNode.zOrder = obj.zsort
          spNode.pos = obj.pos
          layerNode.addChild spNode
          obj.node = spNode

    # assign parent node
    for layer in self.room.layers:
      for obj in layer.objects:
        if obj.parent != "":
          self.room.getObj(obj.parent).node.addChild(obj.node)

    gEngine.tasks.add newNodeRotateTo(1.0, self.room.getObj("robotArm1_1").node, 40, imSwing)
    gEngine.tasks.add newNodeRotateTo(1.0, self.room.getObj("robotArm1Joint1").node, 40, imSwing)
    gEngine.tasks.add newNodeRotateTo(0.25, self.room.getObj("robotArm1Claw").node, -30, imSwing)
    
proc update(self: Engine) =
  var elapsed = 1/60
  self.time += elapsed
  
  # update threads
  for thread in self.threads.toSeq:
    if thread.update(elapsed):
      self.threads.del self.threads.find(thread)

  # update callbacks  
  for cb in self.callbacks.toSeq:
    if cb.update(elapsed):
      self.callbacks.del self.callbacks.find(cb)

  # update tasks
  for t in self.tasks.toSeq:
    if t.update(elapsed):
      self.tasks.del self.tasks.find(t)

  # update audio
  self.audio.update()

  # update room
  self.fade.update(elapsed)
  if not self.room.isNil:
    self.room.update(elapsed)
  
proc render*(self: Engine) =
  self.update()
  
  # draw room
  gfxClear(Gray)
  if not self.room.isNil:
    let fade = if self.fade.enabled: self.fade.current() else: 0.0
    gfxDrawQuad(vec2f(0), vec2f(self.room.roomSize), rgbf(Black, fade))
    camera(self.room.roomSize.x.float32, self.room.roomSize.y.float32)
    self.scene.draw()

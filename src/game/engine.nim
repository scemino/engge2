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
import ../gfx/image
import ../io/ggpackmanager
import ../util/tween
import ../audio/audio
import ../gfx/recti
import ../scenegraph/node
import ../scenegraph/scene
import ../scenegraph/spritenode
import ../util/easing
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
  scene: Node

var gEngine*: Engine
var gRoomId = START_ROOMID

proc newEngine*(v: HSQUIRRELVM): Engine =
  new(result)
  gEngine = result
  result.rand = initRand()
  result.v = v
  result.audio = newAudioSystem()
  result.scene = newScene()
  
  var spriteSheet = loadSpriteSheet("RobotArmsHallSheet.json")
  info "spriteSheet: " & $spriteSheet.frames
  var texture = newTexture(newImage(spriteSheet.meta.image))

  # robotArm1
  var robotArm1Node = newSpriteNode(texture, spriteSheet.frames["arm1"])
  robotArm1Node.pos = vec2(176.0f, 119.0f)
  robotArm1Node.zOrder = 65
  result.scene.addChild(robotArm1Node)

  # robotArm1_1
  var robotArm1_1Node = newSpriteNode(texture, spriteSheet.frames["arm1_1"])
  robotArm1_1Node.pos = vec2(142.0f, 162.0f)
  robotArm1_1Node.zOrder = 62
  result.scene.addChild(robotArm1_1Node)

  # robotArm1Claw
  var robotArm1ClawNode = newSpriteNode(texture, spriteSheet.frames["arm1_claw3"])
  robotArm1ClawNode.zOrder = 64
  robotArm1ClawNode.pos = vec2(104.0f, 126.0f)
  robotArm1_1Node.addChild(robotArm1ClawNode)
  
  # robotArm1Joint1
  var robotArm1Joint1Node = newSpriteNode(texture, spriteSheet.frames["arm1_joint1"])
  robotArm1Joint1Node.zOrder = 64
  robotArm1Joint1Node.pos = vec2(104.0f, 127.0f)
  robotArm1_1Node.addChild(robotArm1Joint1Node)

  gEngine.tasks.add newNodeRotateTo(1.0, robotArm1_1Node, 40, imSwing)
  gEngine.tasks.add newNodeRotateTo(1.0, robotArm1Joint1Node, 40, imSwing)
  gEngine.tasks.add newNodeRotateTo(0.25, robotArm1ClawNode, -30, imSwing)

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

proc setRoom*(self: Engine, room: Room) =
  if self.room != room:
    self.fade.enabled = false
    self.room = room
    call(self.v, self.room.table, "enter")

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
    self.room.render()
    let fade = if self.fade.enabled: self.fade.current() else: 0.0
    gfxDrawQuad(vec2f(0), vec2f(self.room.roomSize), rgbf(Black, fade))
    gfxDrawQuad(vec2f(0), vec2f(self.room.roomSize), self.room.overlay)

  camera(320, 180)
  self.scene.draw()
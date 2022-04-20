import std/[random, streams, tables, sequtils, logging, strformat]
import sqnim
import glm
import room
import thread
import callback
import ids
import task
import ../script/squtils
import ../script/vm
import ../game/motor
import ../gfx/spritesheet
import ../gfx/texture
import ../gfx/graphics
import ../gfx/color
import ../io/ggpackmanager
import ../util/tween
import ../audio/audio
import ../scenegraph/node
import ../scenegraph/scene
import ../scenegraph/parallaxnode
import ../scenegraph/spritenode
from std/times import getTime, toUnix, nanosecond

type Engine* = ref object of RootObj
  rand*: Rand
  randSeed: int64
  spriteSheets: Table[string, SpriteSheet]
  textures: Table[string, Texture]
  v: HSQUIRRELVM
  rooms*: seq[Room]
  actors*: seq[Object]
  currentActor: Object
  room*: Room
  fade*: Tween[float]
  callbacks*: seq[Callback]
  tasks*: seq[Task]
  threads*: seq[Thread]
  time*: float # time in seconds
  audio*: AudioSystem
  scene*: Scene
  cameraPanTo*: Motor

var gEngine*: Engine

proc seedWithTime*(self: Engine) =
  let now = getTime()
  self.randSeed = now.toUnix * 1_000_000_000 + now.nanosecond
  self.rand = initRand(self.randSeed)

proc newEngine*(v: HSQUIRRELVM): Engine =
  new(result)
  gEngine = result
  result.v = v
  result.audio = newAudioSystem()
  result.scene = newScene()
  result.seedWithTime()

proc `seed=`*(self: Engine, seed: int64) =
  self.rand = initRand(seed)

proc `seed`*(self: Engine): int64 =
  self.seed

proc getObj(room: Room, name: string): Object =
  for layer in room.layers:
      for obj in layer.objects:
        if obj.name == name:
          return obj

proc loadRoom*(name: string): Room =
  info "room background: " & name
  let content = gGGPackMgr.loadStream(name & ".wimpy").readAll
  result = parseRoom(content)
  result.scene = newScene()
  getf(gVm.v, gVm.v.rootTbl(), name, result.table)
  result.table.setId(newRoomId())
  for i in 0..<result.layers.len:
    var layer = result.layers[i]
    # create layer node
    var frames: seq[SpriteSheetFrame]
    for name in layer.names:
      frames.add(result.spriteSheet.frames[name])
    var layerNode = newParallaxNode(layer.parallax, result.texture, frames)
    layerNode.zOrder = layer.zSort
    layerNode.name = fmt"Layer {layer.zSort}"
    layer.node = layerNode
    result.scene.addChild layerNode

    for obj in layer.objects:
      sq_resetobject(obj.table)
      getf(gVm.v, result.table, obj.name, obj.table)
      
      # check if the object exists in Squirrel VM
      if obj.table.objType == OT_NULL:
        # this object does not exist, so create it
        sq_newtable(gVm.v)
        discard sq_getstackobj(gVm.v, -1, obj.table)
        sq_addref(gVm.v, obj.table)
        sq_pop(gVm.v, 1)

        # assign an id
        obj.table.setId(newObjId())
        info fmt"Create object with new table: {obj.name} #{obj.id}"

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
        # assign an id
        obj.table.setId(newObjId())
        info fmt"Create object with existing table: {obj.name} #{obj.id}"

      layerNode.addChild obj.node

      if obj.anims.len > 0:
        var ss = obj.getSpriteSheet()
        var frame = ss.frames[obj.anims[0].frames[0]]
        var spNode = newSpriteNode(obj.getTexture(), frame)
        obj.node.addChild spNode

  # assign parent node
  for layer in result.layers:
    for obj in layer.objects:
      if obj.parent != "":
        result.getObj(obj.parent).node.addChild(obj.node)

proc actorExit(self: Engine) =
  if not self.currentActor.isNil and not self.room.isNil:
    if rawExists(self.room.table, "actorExit"):
      call(self.v, self.room.table, "actorExit", [self.currentActor.table])

proc exitRoom(self: Engine, nextRoom: Room) =
  if not self.room.isNil:
    self.actorExit()

    # call room exit function with the next room as a parameter if requested
    let nparams = paramCount(self.v, self.room.table, "exit")
    if nparams == 2:
      call(self.v, self.room.table, "exit", [nextRoom.table])
    else:
      call(self.v, self.room.table, "exit")

    # delete all temporary objects
    for layer in self.room.layers.toSeq:
      for obj in layer.objects:
        if obj.temporary:
          obj.delObject()

    # call global function enteredRoom with the room as argument
    call(self.v, rootTbl(self.v), "exitedRoom", [self.room.table])

    # stop all local threads
    for thread in self.threads:
      if not thread.global:
        thread.stop()

proc actorEnter(self: Engine) =
  if not self.currentActor.isNil:
    # TODO: self.currentActor.stopWalking()
    call(self.v, self.currentActor.table, "actorEnter")
    if not self.room.isNil:
      if rawExists(self.room.table, "actorEnter"):
        call(self.v, self.room.table, "actorEnter", [self.currentActor.table])

proc enterRoom(self: Engine, room: Room, door: Object = nil) =
  ## Called when the room is entered.
  debug fmt"call enter room function of {room.name}"
  self.room = room
  self.scene = room.scene

  # call actor enter function and objects enter function
  self.actorEnter()
  for layer in room.layers:
    for obj in layer.objects:
      if rawExists(obj.table, "enter"):
        call(self.v, obj.table, "enter")

  # call room enter function with the door as a parameter if requested
  let nparams = paramCount(self.v, self.room.table, "enter")
  if nparams == 2:
    call(self.v, self.room.table, "enter", [door.table])
  else:
    call(self.v, self.room.table, "enter")
  
  # call global function enteredRoom with the room as argument
  call(self.v, rootTbl(self.v), "enteredRoom", [room.table])

proc setRoom*(self: Engine, room: Room) =
  if self.room != room:
    self.fade.enabled = false
    self.exitRoom(room)
    self.enterRoom(room)

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

  # update motors
  if not self.cameraPanTo.isNil:
    self.cameraPanTo.update(elapsed)

  # update room
  self.fade.update(elapsed)
  if not self.room.isNil:
    self.room.update(elapsed)

  # update actors
  for actor in self.actors.mitems:
    actor.update(elapsed)

proc clampPos(self: Engine, at: Vec2f): Vec2f =
  var screenSize = self.room.getScreenSize()
  var x = clamp(at.x, 0.0f, max(self.room.roomSize.x.float32 - screenSize.x.float32, 0.0f))
  var y = clamp(at.y, 0.0f, max(self.room.roomSize.y.float32 - screenSize.y.float32, 0.0f))
  vec2(x, y)

proc cameraAt*(self: Engine, at: Vec2f) =
  ## Set the camera position to the given `at` position.
  cameraPos(self.clampPos(at))

proc cameraPos*(self: Engine): Vec2f =
  ## Returns the camera position: the position of the middle of the screen.
  let screenSize = self.room.getScreenSize()
  cameraPos() + vec2(screenSize.x.float32, screenSize.y.float32) / 2.0f

proc render*(self: Engine) =
  self.update()
  
  # draw room
  gfxClear(Gray)
  if not self.room.isNil:
    var camSize = self.room.getScreenSize()
    camera(camSize.x.float32, camSize.y.float32)
    
  self.scene.draw()

  # draw fade
  let fade = if self.fade.enabled: self.fade.current() else: 0.0
  gfxDrawQuad(vec2f(0), camera(), rgbaf(Black, fade))
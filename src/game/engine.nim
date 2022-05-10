import std/[random, streams, tables, sequtils, logging, strformat]
import sqnim
import glm
import room
import thread
import callback
import ids
import task
import inputstate
import verb
import hud
import resmanager
import ../script/squtils
import ../script/vm
import ../game/motors/motor
import ../game/prefs
import ../gfx/spritesheet
import ../gfx/texture
import ../gfx/graphics
import ../gfx/color
import ../gfx/recti
import ../io/ggpackmanager
import ../util/tween
import ../audio/audio
import ../scenegraph/node
import ../scenegraph/scene
import ../scenegraph/parallaxnode
import ../scenegraph/spritenode
import ../sys/app
from std/times import getTime, toUnix, nanosecond

const
  ScreenWidth = 1280 
  ScreenHeight = 720

type
  Engine* = ref object of RootObj
    rand*: Rand
    randSeed: int64
    spriteSheets: Table[string, SpriteSheet]
    textures: Table[string, Texture]
    v: HSQUIRRELVM
    rooms*: seq[Room]
    actors*: seq[Object]
    actor*: Object
    room*: Room
    fade*: Tween[float]
    callbacks*: seq[Callback]
    tasks*: seq[Task]
    threads*: seq[Thread]
    time*: float # time in seconds
    audio*: AudioSystem
    scene*: Scene
    screen*: Scene
    cameraPanTo*: Motor
    inputState*: InputState
    noun1*: Object
    hud*: Hud
    prefs*: Preferences
    defaultObj*: HSQOBJECT

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
  result.screen = newScene()
  result.seedWithTime()
  result.inputState = newInputState()
  result.screen.addChild result.inputState.node
  result.prefs.init()
  sq_resetobject(result.defaultObj)

proc `seed=`*(self: Engine, seed: int64) =
  self.rand = initRand(seed)

proc `seed`*(self: Engine): int64 =
  self.seed

proc `currentActor`*(self: Engine): Object =
  self.actor

proc follow(self: Engine, actor: Object) =
  # TODO: follows actor
  discard

proc setCurrentActor*(self: Engine, actor: Object, userSelected = false) =
  self.actor = actor
  # TODO:
  # call("onActorSelected", [actor.table, userSelected])
  # let room = if actor.isNil: nil else: actor.room
  # if not room.isNil:
  #   if room.table.rawExists("onActorSelected"):
  #     room.table.call("onActorSelected", [actor, userSelected])

  # if not actor.isNil:
  #   self.follow(actor)

proc getObj(room: Room, name: string): Object =
  for layer in room.layers:
      for obj in layer.objects:
        if obj.name == name:
          return obj

proc defineRoom*(name: string, table: HSQOBJECT): Room =
  info "load room: " & name
  if name == "Void":
    result = Room(name: name, table: table)
  else:
    var background: string
    table.getf("background", background)
    result = Room(name: name, table: table)
    let content = gGGPackMgr.loadStream(background & ".wimpy").readAll
    result = parseRoom(table, content)
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
        result.table.getf(obj.name, obj.table)
        
        # check if the object exists in Squirrel VM
        if obj.table.objType == OT_NULL:
          # this object does not exist, so create it
          sq_newtable(gVm.v)
          discard sq_getstackobj(gVm.v, -1, obj.table)
          sq_addref(gVm.v, obj.table)
          sq_pop(gVm.v, 1)

          # assign an id
          obj.table.setId(newObjId())
          # info fmt"Create object with new table: {obj.name} #{obj.id}"

          # assign a name
          sq_pushobject(gVm.v, obj.table)
          sq_pushstring(gVm.v, "name", -1)
          sq_pushstring(gVm.v, obj.name, -1)
          discard sq_newslot(gVm.v, -3, false)

          obj.touchable = true
          
          # adds the object to the room table
          sq_pushobject(gVm.v, result.table)
          sq_pushstring(gVm.v, obj.name, -1)
          sq_pushobject(gVm.v, obj.table)
          discard sq_newslot(gVm.v, -3, false)
          sq_pop(gVm.v, 1)
          obj.setRoom(result)
        else:
          # assign an id
          obj.table.setId(newObjId())
          info fmt"Create object with existing table: {obj.name} #{obj.id}"
          if obj.table.rawexists("initTouchable"):
            obj.table.getf("initTouchable", obj.touchable)
          else:
            obj.touchable = true
          if obj.table.rawexists("initState"):
            var state: int
            obj.table.getf("initState", state)
            obj.setState(state)
          # is it an inventory object
          if obj.table.rawexists("icon"):
            # adds it to the root table
            info fmt"Add {obj.name} to inventory"
            setf(rootTbl(gVm.v), obj.name, obj.table)
          obj.setRoom(result)

        layerNode.addChild obj.node

        if obj.anims.len > 0 and obj.anims[0].frames.len > 0:
          var ss = obj.getSpriteSheet()
          if obj.anims[0].frames[0] != "null":
            var frame = ss.frames[obj.anims[0].frames[0]]
            var spNode = newSpriteNode(obj.getTexture(), frame)
            obj.node.addChild spNode

    # assign parent node
    for layer in result.layers:
      for obj in layer.objects:
        if obj.parent != "":
          result.getObj(obj.parent).node.addChild(obj.node)
  
  # declare the room in the root table
  result.table.setId(newRoomId())
  setf(rootTbl(gVm.v), name, result.table)

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
    call("exitedRoom", [self.room.table])

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
  call("enteredRoom", [room.table])

proc setRoom*(self: Engine, room: Room) =
  if self.room != room:
    self.fade.enabled = false
    self.exitRoom(room)
    self.enterRoom(room)

proc findObjAt(self: Engine, pos: Vec2f): Object =
  for layer in gEngine.room.layers:
    for obj in layer.objects:
      if obj.node.visible and obj.objType == otNone and obj.contains(pos):
        return obj

proc winToScreen(self: Engine, pos: Vec2f): Vec2f =
  result = (pos / vec2f(appGetWindowSize())) * vec2(1280f, 720f)
  result = vec2(result.x, 720f - result.y)

proc verbNoWalkTo(verbId: VerbId, noun1: Object): bool =
  if verbId == VERB_LOOKAT:
    result = (noun1.flags and FAR_LOOK) != 0

proc callVerb*(actor: Object, verbId: VerbId, noun1: Object, noun2: Object = nil): bool =
  # Called after the actor has walked to the object.
  let name = if actor.isNil: "currentActor" else: actor.name
  let noun1name = if noun1.isNil: "null" else: noun1.name
  let noun2name = if noun2.isNil: "null" else: noun2.name
  let verbFuncName = gEngine.hud.actorSlot(actor).verbs[verbId.int].fun
  info fmt"callVerb({name},{verbFuncName},{noun1name},{noun2name})"

  # TODO: gEngine.selectedActor.stopWalking()
  # test if object became untouchable
  if not noun1.inInventory and not noun1.touchable: 
    return false
  if not noun2.isNil and not noun2.inInventory and not noun2.touchable: 
    return false

  # TODO: Do reach before calling verb so we can kill it if needed.

  # TODO: finish this
  call(noun1.table, verbFuncName)

  gEngine.noun1 = nil

import actor

proc execSentence(actor: Object, verbId: int, noun1: Object; noun2: Object = nil): bool =
  ## Called to execute a sentence and, if needed, start the actor walking.
  ## If `actor` is `null` then the selectedActor is assumed.
  let name = if actor.isNil: "currentActor" else: actor.name
  let noun1name = if noun1.isNil: "null" else: noun1.name
  let noun2name = if noun2.isNil: "null" else: noun2.name
  info fmt"exec({name},{verbId.VerbId},{noun1name},{noun2name})"
  var a = actor
  if a.isNil: a = gEngine.currentActor
  if verbId <= 0 and verbId > 13 or noun1.isNil:
    return false
  # TODO
  #if (a?._verb_tid) stopthread(actor._verb_tid)

  info fmt"noun1.inInventory: {noun1.inInventory} and noun1.touchable: {noun1.touchable} nowalk: {verbNoWalkTo(verbId.VerbId, noun1)}"
  
  # test if object became untouchable
  if not noun1.inInventory and not noun1.touchable: 
    return false
  if not noun2.isNil and not noun2.inInventory and not noun2.touchable: 
    return false

  if noun1.inInventory:
    if noun2.isNil or noun2.inInventory:
      discard callVerb(a, verbId.VerbId, noun1, noun2)
      return true
  
  if verbNoWalkTo(verbId.VerbId, noun1):
    if not noun1.inInventory: # TODO: test if verb.flags != VERB_INSTANT
      # TODO: actor.actorTurnTo(noun1)
      discard callVerb(a, verbId.VerbId, noun1, noun2)
      return true

  a.exec = newSentence(verbId.VerbId, noun1, noun2)
  if not inInventory(noun1):
    a.walk(noun1)
  else:
    a.walk(noun2)

proc cancelSentence(actor: Object) =
  var actor = actor
  if actor.isNil: 
    actor = gEngine.actor
  if not actor.isNil:
    actor.exec = nil

proc clickedAt(self: Engine, scrPos: Vec2f, btns: MouseButtonMask) =
  # TODO: WIP
  if not self.room.isNil:
    let roomPos = self.room.screenToRoom(scrPos)
    let obj = self.findObjAt(roomPos)

    # button right: execute default verb
    if mbRight in btns and not obj.isNil:
      if obj.table.rawexists("defaultVerb"):
        var defVerbId: int
        obj.table.getf("defaultVerb", defVerbId)
        let verbName = gEngine.hud.actorSlot(gEngine.actor).verbs[defVerbId.int].fun
        if obj.table.rawexists(verbName):
          discard execSentence(nil, defVerbId, self.noun1)
    else:
      # Just clicking on the ground
      cancelSentence(gEngine.actor)
      gEngine.actor.walk(room_pos)

  # TODO: call calbacks

proc update(self: Engine) =
  let elapsed = 1/60
  self.time += elapsed

  # update mouse pos
  let scrPos = self.winToScreen(mousePos())
  self.inputState.node.pos = scrPos
  if not self.room.isNil:
    let roomPos = self.room.screenToRoom(scrPos)
    self.noun1 = self.findObjAt(roomPos)
    var txt = if self.noun1.isNil: "" else: self.noun1.name
    self.inputState.setText(txt)

  # call clickedAt if any button down
  let btns = mouseBtns()
  if btns.len > 0:
    self.clickedAt(scrPos, btns)

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

proc drawHud*(self: Engine) =
  if not self.actor.isNil:
    let actorSlot = self.hud.actorSlot(self.actor)
    let gameSheet = gResMgr.spritesheet("GameSheet")

    # draw UI backing
    var frame = gameSheet.frames["ui_backing"]
    let texture = gResMgr.texture(gameSheet.meta.image)
    let uiBackingColor = rgbaf(0f, 0f, 0f, 0.33f)
    gfxDrawSprite(frame.frame / texture.size, texture, uiBackingColor)

    # draw verbs
    let verbSheet = gResMgr.spritesheet("VerbSheet")
    var verbTexture = gResMgr.texture(verbSheet.meta.image)
    for i in 1..<actorSlot.verbs.len:
      let verb = actorSlot.verbs[i]
      let verbFrame = verbSheet.frames[fmt"{verb.image}_en"]
      var pos = vec2(verbFrame.spriteSourceSize.x.float32, verbFrame.sourceSize.y.float32 - verbFrame.spriteSourceSize.y.float32 - verbFrame.spriteSourceSize.h.float32)
      gfxDrawSprite(pos, verbFrame.frame / verbTexture.size, verbTexture, actorSlot.verbUiColors.verbNormal)

    # draw scroll up
    frame = gameSheet.frames["scroll_up"]
    var pos = vec2(ScreenWidth/2f, frame.sourceSize.y.float32)
    gfxDrawSprite(pos, frame.frame / texture.size, texture, actorSlot.verbUiColors.verbNormal)
    
    # draw scroll down
    frame = gameSheet.frames["scroll_down"]
    pos = vec2(ScreenWidth/2f, frame.sourceSize.y.float32 - frame.spriteSourceSize.y.float32 - frame.spriteSourceSize.h.float32)
    gfxDrawSprite(pos, frame.frame / texture.size, texture, actorSlot.verbUiColors.verbNormal)

    # draw inventory background
    let startOffsetX = ScreenWidth/2f + frame.sourceSize.x.float32 + 4
    var offsetX = startOffsetX
    frame = gameSheet.frames["inventory_background"]
    for i in 1..4:
      pos = vec2(offsetX, frame.sourceSize.y.float32 - frame.spriteSourceSize.y.float32 - frame.spriteSourceSize.h.float32 + 4f)
      gfxDrawSprite(pos, frame.frame / texture.size, texture, actorSlot.verbUiColors.inventoryBackground)
      offsetX += frame.sourceSize.x.float32 + 4f
    offsetX = startOffsetX
    for i in 1..4:
      pos = vec2(offsetX, 2*frame.sourceSize.y.float32 - frame.spriteSourceSize.y.float32 - frame.spriteSourceSize.h.float32 + 8f)
      gfxDrawSprite(pos, frame.frame / texture.size, texture, actorSlot.verbUiColors.inventoryBackground)
      offsetX += frame.sourceSize.x.float32 + 4f

proc render*(self: Engine) =
  self.update()
  
  # draw scene
  gfxClear(Gray)
  if not self.room.isNil:
    var camSize = self.room.getScreenSize()
    camera(camSize.x.float32, camSize.y.float32)
    
  self.scene.draw()
  # if not self.room.isNil:
    # for wb in self.room.walkboxes:
    #   var vert: seq[Vertex]
    #   let color = if wb.visible: Green else: Red
    #   for pt in wb.polygon:
    #     vert.add newVertex(pt.x.float32, pt.y.float32, color)
    #   gfxDrawLineLoop(vert)
  
    # var vert: seq[Vertex]
    # for walkbox in self.room.mergedPolygon:
    #   for pt in walkbox.polygon:
    #     vert.add newVertex(pt.x.float32, pt.y.float32, Orange)
    # gfxDrawLineLoop(vert)

  # draw screen
  camera(ScreenWidth, ScreenHeight)
  self.drawHud()
  self.screen.draw()

  # draw fade
  let fade = if self.fade.enabled: self.fade.current() else: 0.0
  gfxDrawQuad(vec2f(0), camera(), rgbaf(Black, fade))

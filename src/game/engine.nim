import std/[random, streams, sequtils, logging, strformat, times]
import sqnim
import glm
import room
import thread
import callback
import ids
import tasks/task
import inputstate
import screen
import verb
import shaders
import inputmap
import motors/motor
import ../audio/audio
import ../script/squtils
import ../script/flags
import ../script/vm
import ../gfx/spritesheet
import ../gfx/graphics
import ../gfx/shader
import ../gfx/color
import ../gfx/recti
import ../gfx/texture
import ../io/ggpackmanager
import ../io/textdb
import ../util/tween
import ../scenegraph/node
import ../scenegraph/scene
import ../scenegraph/parallaxnode
import ../scenegraph/hud
import ../scenegraph/walkboxnode
import ../scenegraph/dialog
import ../scenegraph/actorswitcher
import ../scenegraph/optionsdlg
import ../scenegraph/inventory
import ../game/states/dlgstate
import ../game/states/state
import ../sys/app
import ../util/common

const
  ScreenMargin = 100f
  DOOR_LEFT = 0x140
  DOOR_RIGHT = 0x240
  DOOR_BACK = 0x440
  DOOR_FRONT = 0x840
type
  Engine* = ref object of RootObj
    rand*: Rand
    randSeed: int64
    v: HSQUIRRELVM
    rooms*: seq[Room]
    room*: Room
    actors*: seq[Object]
    actor*: Object
    fade*: Tween[float] # will be removed by a shader
    callbacks*: seq[Callback]
    tasks*: seq[Task]
    threads*: seq[ThreadBase]
    time*: float # time in seconds
    audio*: AudioSystem
    scene*: Scene
    screen*: Scene
    ui*: Scene
    cameraPanTo*: Motor
    inputState*: InputState
    noun1*: Object
    noun2*: Object
    useFlag: UseFlag
    defaultObj*: HSQOBJECT
    hud*: Hud
    inventory*: seq[Object]
    cutscene*: ThreadBase
    roomShader: Shader
    followActor*: Object
    mouseDownTime: DateTime
    walkFastState: bool
    walkboxNode*: WalkboxNode
    bounds*: Recti
    frameCounter*: int
    dlg*: Dialog
    uiInv*: Inventory
    actorswitcher*: Actorswitcher
    mouseState*: MouseState

var gEngine*: Engine

proc seedWithTime*(self: Engine) =
  let now = getTime()
  self.randSeed = now.toUnix * 1_000_000_000 + now.nanosecond
  self.rand = initRand(self.randSeed)

proc selectActor(index: int)
proc selectNextActor()
proc selectPrevActor()
proc takeScreenshot()
proc selectChoice(index: int)
proc soundObjVol(self: SoundId): float32

proc newEngine*(v: HSQUIRRELVM): Engine =
  new(result)
  gEngine = result
  result.v = v
  result.audio = newAudioSystem(soundObjVol)
  result.scene = newScene()
  result.screen = newScene()
  result.hud = newHud()
  result.seedWithTime()
  result.inputState = newInputState()
  result.dlg = newDialog()
  result.ui = newScene()
  result.actorswitcher = newActorSwitcher()
  result.uiInv = newInventory()
  result.screen.addChild result.inputState.node
  result.screen.addChild result.dlg
  result.screen.addChild result.uiInv
  result.screen.addChild result.actorswitcher
  result.screen.addChild result.ui
  sq_resetobject(result.defaultObj)

  regCmdFunc(GameCommand.SelectActor1, proc () = selectActor(0))
  regCmdFunc(GameCommand.SelectActor2, proc () = selectActor(1))
  regCmdFunc(GameCommand.SelectActor3, proc () = selectActor(2))
  regCmdFunc(GameCommand.SelectActor4, proc () = selectActor(3))
  regCmdFunc(GameCommand.SelectActor5, proc () = selectActor(4))
  regCmdFunc(GameCommand.SelectActor6, proc () = selectActor(5))
  regCmdFunc(GameCommand.SelectNextActor, proc () = selectNextActor())
  regCmdFunc(GameCommand.SelectPreviousActor, proc () = selectPrevActor())
  regCmdFunc(GameCommand.SelectChoice1, proc () = selectChoice(0))
  regCmdFunc(GameCommand.SelectChoice2, proc () = selectChoice(1))
  regCmdFunc(GameCommand.SelectChoice3, proc () = selectChoice(2))
  regCmdFunc(GameCommand.SelectChoice4, proc () = selectChoice(3))
  regCmdFunc(GameCommand.SelectChoice5, proc () = selectChoice(4))
  regCmdFunc(GameCommand.SelectChoice6, proc () = selectChoice(5))
  regCmdFunc(GameCommand.Screenshot, proc () = takeScreenshot())

proc `seed=`*(self: Engine, seed: int64) =
  self.randSeed = seed
  self.rand = initRand(seed)

proc `seed`*(self: Engine): int64 =
  self.randSeed

proc `currentActor`*(self: Engine): Object =
  self.actor

proc getObj(room: Room, key: string): Object =
  for layer in room.layers:
      for obj in layer.objects:
        if obj.key == key:
          return obj

proc defineRoom*(name: string, table: HSQOBJECT, pseudo = false): Room =
  info "Load room: " & name
  if name == "Void":
    result = Room(name: name, table: table)
    result.table.setId(newRoomId())
    result.scene = newScene()
    var layer = newLayer(@["background"], vec2(1f, 1f), 0)
    layer.node = newParallaxNode(vec2(1f, 1f), gEmptyTexture, @[])
    result.layers.add(layer)
    result.scene.addChild layer.node
    setf(rootTbl(gVm.v), name, result.table)
  else:
    var background: string
    table.getf("background", background)
    let content = gGGPackMgr.loadStream(background & ".wimpy").readAll
    result = parseRoom(table, content)
    result.pseudo = pseudo
    result.name = name
    for i in 0..<result.layers.len:
      let layer = result.layers[i]
      # create layer node
      var frames: seq[SpriteSheetFrame]
      for name in layer.names:
        frames.add(result.spriteSheet.frame(name))
      var layerNode = newParallaxNode(layer.parallax, result.texture, frames)
      layerNode.zOrder = layer.zSort
      layerNode.name = fmt"Layer {layer.names}({layer.zSort})"
      layer.node = layerNode
      result.scene.addChild layerNode

      for obj in layer.objects:
        if not table.rawexists(obj.key):
          # this object does not exist, so create it
          sq_newtable(gVm.v)
          discard sq_getstackobj(gVm.v, -1, obj.table)
          sq_addref(gVm.v, obj.table)
          sq_pop(gVm.v, 1)

          # assign an id
          obj.table.setId(newObjId())
          # info fmt"Create object with new table: {obj.name} #{obj.id}"

          # adds the object to the room table
          setf(result.table, obj.key, obj.table)
          obj.setRoom(result)
          obj.setState(0, true)

        layerNode.addChild obj.node

    # assign parent node
    for layer in result.layers:
      for obj in layer.objects:
        if obj.parent != "":
          let parent = result.getObj(obj.parent)
          if parent.isNil:
            warn "parent: '" & obj.parent & "' not found"
          else:
            parent.node.addChild(obj.node)
  
  for (k, v) in result.table.mpairs:
    if v.objType == OT_TABLE:
      if pseudo:
        # if it's a pseudo room we need to clone each object
        sq_pushobject(gVm.v, v)
        discard sq_clone(gVm.v, -1)
        discard sq_getstackobj(gVm.v, -1, v)
        sq_addref(gVm.v, v)
        sq_pop(gVm.v, 2)
        setf(result.table, k, v)

      if v.rawexists("icon"):
        # Add inventory object to root table
        info fmt"Add {k} to inventory"
        setf(rootTbl(gVm.v), k, v)

        # set room as delegate
        v.setdelegate(table)

        # declare flags if does not exist
        if not v.rawexists("flags"):
          v.setf("flags", 0)
        let obj = Object(table: v, key: k)
        obj.table.setId(newObjId())
        obj.node = newNode(k)
        obj.nodeAnim = newAnim(obj)
        obj.node.addChild obj.nodeAnim
        gEngine.inventory.add obj
      else:
        var obj = result.getObj(k)
        if obj.isNil:
          info fmt"object: {k} not found in wimpy"
          if v.rawexists("name"):
            obj = newObject()
            obj.key = k
            obj.layer = result.layer(0)
            result.layer(0).objects.add obj
          else:
            continue
        
        getf(result.table, k, obj.table)
        obj.table.setId(newObjId())
        info fmt"Create object: {k} #{obj.id}"
        
        # add it to the root table if not a pseudo room
        if not pseudo:
          setf(rootTbl(gVm.v), k, obj.table)
        
        if obj.table.rawexists("initState"):
          # info fmt"initState {obj.key}"
          var state: int
          obj.table.getf("initState", state)
          obj.setState(state, true)
        else:
          obj.setState(0, true)
        obj.setRoom(result)

        # set room as delegate
        obj.table.setdelegate(table)

        # declare flags if does not exist
        if not obj.table.rawexists("flags"):
          obj.table.setf("flags", 0)

  # declare the room in the root table
  result.table.setId(newRoomId())
  setf(rootTbl(gVm.v), name, result.table)

proc actorExit(self: Engine) =
  if not self.currentActor.isNil and not self.room.isNil:
    if rawExists(self.room.table, "actorExit"):
      call(self.v, self.room.table, "actorExit", [self.currentActor.table])

proc exitRoom(self: Engine, nextRoom: Room) =
  self.audio.stopAll()
  if not self.room.isNil:
    self.room.triggers.setLen 0

    self.actorExit()

    # call room exit function with the next room as a parameter if requested
    let nparams = paramCount(self.v, self.room.table, "exit")
    if nparams == 2:
      sqCall(self.room.table, "exit", [nextRoom.table])
    else:
      call(self.room.table, "exit")

    # delete all temporary objects
    for layer in self.room.layers:
      for obj in layer.objects.toSeq:
        if obj.temporary:
          obj.delObject()

    # call global function enteredRoom with the room as argument
    call("exitedRoom", [self.room.table])

    # stop all local threads
    for thread in self.threads:
      if not thread.global:
        thread.stop()
    
    # stop all lights
    self.room.numLights = 0

proc actorEnter(self: Engine) =
  if not self.currentActor.isNil:
    # TODO: self.currentActor.stopWalking()
    call(self.v, self.currentActor.table, "actorEnter")
    if not self.room.isNil:
      if rawExists(self.room.table, "actorEnter"):
        call(self.v, self.room.table, "actorEnter", [self.currentActor.table])

proc getVerb(self: Engine, id: int): Verb

proc enterRoom*(self: Engine, room: Room, door: Object = nil) =
  ## Called when the room is entered.
  debug fmt"call enter room function of {room.name}"

  # exit current room
  self.fade.enabled = false
  self.exitRoom(self.room)

  # sets the current room for scripts
  rootTbl(gVm.v).setf("currentRoom", room.table)

  self.room = room
  self.scene = room.scene
  self.room.numLights = 0
  if not self.walkboxNode.isNil:
    self.walkboxNode.remove()
  self.walkboxNode = newWalkboxNode(room)
  self.scene.addChild self.walkboxNode
  self.bounds = rectFromMinMax(vec2(0'i32,0'i32), room.roomSize)
  self.hud.verb = self.getVerb(VERB_WALKTO)

  # move current actor to the new room
  if not door.isNil and not gEngine.actor.isNil:
    gEngine.actor.room = room
    if not door.isNil:
      gEngine.actor.node.pos = door.getUsePos

  # call actor enter function and objects enter function
  self.actorEnter()
  for layer in room.layers:
    for obj in layer.objects:
      if rawExists(obj.table, "enter"):
        call(self.v, obj.table, "enter")

  # call room enter function with the door as a parameter if requested
  let nparams = paramCount(self.v, self.room.table, "enter")
  if nparams == 2:
    if door.isNil:
      var doorTable: HSQOBJECT
      sq_resetobject(doorTable)
      call(self.v, self.room.table, "enter", [doorTable])
    else:
      call(self.v, self.room.table, "enter", [door.table])
  else:
    call(self.v, self.room.table, "enter")
  
  # call global function enteredRoom with the room as argument
  call("enteredRoom", [room.table])

proc setRoom*(self: Engine, room: Room) =
  if not room.isNil and self.room != room:
    self.enterRoom(room)
    self.bounds = rectFromMinMax(vec2(0'i32,0'i32), room.roomSize)

proc inInventory*(obj: Object): bool =
  gEngine.inventory.contains obj

iterator roomObjs*(self: Engine): Object =
  for room in self.rooms:
    for layer in room.layers:
      for o in layer.objects:
        yield o

iterator objsAt*(self: Engine, pos: Vec2f): Object =
  if not self.uiInv.obj.isNil and self.room.fullscreen == FullscreenRoom:
    yield self.uiInv.obj
  for layer in gEngine.room.layers:
    for obj in layer.objects.ritems:
      if obj != self.actor and (obj.touchable or obj.inInventory()) and obj.node.visible and obj.objType == otNone and obj.contains(pos):
        yield obj

proc objAt*(self: Engine, pos: Vec2f): Object =
  var zOrder = int32.high
  for obj in self.objsAt(pos):
    if obj.node.zOrder < zOrder:
      result = obj
      zOrder = obj.node.zOrder

proc objAt*(self: Engine, pos: Vec2f, pred: proc(x: Object): bool): Object =
  for obj in self.objsAt(pos):
    if pred(obj):
      return obj

proc objAt*(self: Engine, pos: Vec2f, flags: int): Object =
  self.objAt(pos, proc (x: Object): bool = x.getFlags().hasFlag(flags))

proc inventoryAt*(self: Engine, pos: Vec2f): Object =
  self.objAt(pos, proc (x: Object): bool = x.inInventory())

proc winToScreen*(pos: Vec2f): Vec2f =
  result = (pos / vec2f(appGetWindowSize())) * vec2(ScreenWidth, ScreenHeight)
  result = vec2(result.x, ScreenHeight - result.y)

proc verbNoWalkTo(verbId: VerbId, noun1: Object): bool =
  if verbId == VERB_LOOKAT:
    result = (noun1.flags and FAR_LOOK) != 0

proc giveTo(actor1, actor2, obj: Object) =
  obj.owner = actor2
  actor2.inventory.add obj
  let index = actor1.inventory.find obj
  if index != -1:
    actor1.inventory.del index
  
proc callVerb*(self: Engine, actor: Object, verbId: VerbId, noun1: Object, noun2: Object = nil): bool =
  sqCall("onObjectClick", [noun1.table])

  # Called after the actor has walked to the object.
  let name = if actor.isNil: "currentActor" else: actor.key
  let noun1name = if noun1.isNil: "null" else: noun1.key
  let noun2name = if noun2.isNil: "null" else: noun2.key
  let verbFuncName = gEngine.hud.actorSlot(actor).verb(verbId).fun
  info fmt"callVerb({name},{verbFuncName},{noun1name},{noun2name})"

  # TODO: gEngine.selectedActor.stopWalking()
  # test if object became untouchable
  if not noun1.inInventory and not noun1.touchable: 
    return false
  if not noun2.isNil and not noun2.inInventory and not noun2.touchable: 
    return false

  # TODO: Do reach before calling verb so we can kill it if needed.

  # check if verb is use and object can be used with or in or on
  if verbId == VERB_USE and noun2.isNil:
    self.useFlag = noun1.useFlag()
    if self.useFlag != ufNone:
      self.noun1 = noun1
      return

  if verbId == VERB_GIVE:
    if noun2.isNil:
      info "set use flag to ufGiveTo"
      self.useFlag = ufGiveTo
      self.noun1 = noun1
    else:
      var handled: bool
      if noun2.table.rawExists(verbFuncName):
        info fmt"call {verbFuncName} on {noun2.key}"
        noun2.table.call(verbFuncName, [noun1.table])
        handled = true
      if noun1.table.rawExists(verbFuncName):
        info fmt"call {verbFuncName} on {noun1.key}"
        noun1.table.call(verbFuncName, [noun2.table])
        handled = true
      if not handled and noun2.table.rawExists(verbFuncName):
        info fmt"call {verbFuncName} on actor {noun2.key}"
        noun2.table.callFunc(verbFuncName, [noun1.table])
        handled = true
      if not handled:
        info "call objectGive"
        call("objectGive", [noun1.table, self.actor.table, noun2.table])
        self.actor.giveTo(noun2, noun1)
    return

  if noun2.isNil:
    if noun1.table.rawExists(verbFuncName):
      let count = gVm.v.paramCount(noun1.table, verbFuncName)
      info fmt"call {noun1.key}.{verbFuncName}"
      if count == 1:
        call(noun1.table, verbFuncName)
      else:
        call(noun1.table, verbFuncName, [actor.table])
    else:
      info fmt"call defaultObject.{verbFuncName}"
      var nilObj: HSQOBJECT
      call(self.defaultObj, verbFuncName, [noun1.table, nilObj])
  else:
    if noun1.table.rawExists(verbFuncName):
      info fmt"call {noun1.key}.{verbFuncName}"
      call(noun1.table, verbFuncName, [noun2.table])
    else:
      info fmt"call defaultObject.{verbFuncName}"
      call(self.defaultObj, verbFuncName, [noun1.table, noun2.table])

  # TODO: finish this

  if verbId == VERB_PICKUP:
    call("onPickup", [noun1.table, self.actor.table])

  info "reset nouns"
  gEngine.noun1 = nil
  gEngine.noun2 = nil
  gEngine.useFlag = ufNone

import actor

proc preWalk(self: Engine, actor: Object, verbId: VerbId, noun1: Object; noun2: Object): bool =
  var n2Table: HSQOBJECT
  var n2Name: string
  if not noun2.isNil:
    n2Table = noun2.table
    n2Name = fmt"{noun2.name}({noun2.key})"
  else:
    sq_resetobject(n2Table)
  if actor.table.rawexists("actorPreWalk"):
    info fmt"actorPreWalk {verbId} n1={noun1.name}({noun1.key}) n2={n2Name}"
    actor.table.sqCallFunc(result, "actorPreWalk", [verbId.int32, noun1.table, n2Table])
  if not result:
    let funcName = if noun1.id.isActor: "actorPreWalk" else: "objectPreWalk"
    if rawexists(noun1.table, funcName):
      noun1.table.sqCallFunc(result, funcName, [verbId.int32, noun1.table, n2Table])
      info fmt"{funcName} {verbId} n1={noun1.name}({noun1.key}) n2={n2Name} -> {result}"

proc execSentence*(self: Engine, actor: Object, verbId: VerbId, noun1: Object; noun2: Object = nil): bool =
  ## Called to execute a sentence and, if needed, start the actor walking.
  ## If `actor` is `null` then the selectedActor is assumed.
  let name = if actor.isNil: "currentActor" else: actor.key
  let noun1name = if noun1.isNil: "null" else: noun1.key
  let noun2name = if noun2.isNil: "null" else: noun2.key
  info fmt"exec({name},{verbId.VerbId},{noun1name},{noun2name})"
  var actor = if actor.isNil: gEngine.currentActor else: actor
  if verbId <= 0 and verbId > 13 or noun1.isNil or actor.isNil:
    return false
  # TODO
  #if (a?._verb_tid) stopthread(actor._verb_tid)

  info fmt"noun1.inInventory: {noun1.inInventory} and noun1.touchable: {noun1.touchable} nowalk: {verbNoWalkTo(verbId, noun1)}"
  
  # test if object became untouchable
  if not noun1.inInventory and not noun1.touchable: 
    return false
  if not noun2.isNil and not noun2.inInventory and not noun2.touchable: 
    return false

  if noun1.inInventory:
    if noun2.isNil or noun2.inInventory:
      discard self.callVerb(actor, verbId, noun1, noun2)
      return true
  
  if self.preWalk(actor, verbId, noun1, noun2):
    return true

  if verbNoWalkTo(verbId, noun1):
    if not noun1.inInventory: # TODO: test if verb.flags != VERB_INSTANT
      actor.turn(noun1)
      discard self.callVerb(actor, verbId, noun1, noun2)
      return true

  actor.exec = newSentence(verbId, noun1, noun2)
  if not inInventory(noun1):
    actor.walk(noun1)
  else:
    actor.walk(noun2)
  return true

proc cancelSentence(self: Engine, actor: Object) =
  info("cancelSentence")
  var actor = actor
  if actor.isNil: 
    actor = gEngine.actor
  if not actor.isNil:
    actor.exec = nil

proc clickedAtHandled(self: Engine, roomPos: Vec2f): bool =
  let x = roomPos.x.int
  let y = roomPos.y.int
  if self.room.table.rawexists("clickedAt"):
    info "clickedAt " & $[x, y]
    self.room.table.callFunc(result, "clickedAt", [x, y])
  if not result:
    if not self.actor.isNil and self.actor.table.rawexists("clickedAt"):
      self.actor.table.callFunc(result, "clickedAt", [x, y])

proc getVerb(self: Engine, id: int): Verb =
  if not self.actor.isNil:
    for verb in self.hud.actorSlot(self.actor).verbs:
      if verb.id == id:
        return verb  

proc clickedAt(self: Engine, scrPos: Vec2f) =
  # TODO: WIP
  if not self.room.isNil and self.inputState.inputActive:
    let roomPos = self.room.screenToRoom(scrPos)
    let obj = self.objAt(roomPos)

    if self.mouseState.click():
      # button left: execute selected verb
      var handled = self.clickedAtHandled(roomPos)
      if not handled and not obj.isNil:
        let verb = self.hud.verb
        handled = self.execSentence(nil, verb.id, self.noun1, self.noun2)
      if not handled:
        if not self.actor.isNil and scrPos.y > 172:
          self.actor.walk(room_pos)
          self.hud.verb = self.getVerb(VERB_WALKTO)
        # Just clicking on the ground
        self.cancelSentence(self.actor)
    elif self.mouseState.click(mbRight):
      # button right: execute default verb
      if not obj.isNil:
        var defVerbId = VERB_LOOKAT
        if obj.table.rawexists("defaultVerb"):
          obj.table.getf("defaultVerb", defVerbId)
        discard self.execSentence(nil, defVerbId, self.noun1, self.noun2)
    elif self.walkFastState and self.mouseState.pressed() and not self.actor.isNil and scrPos.y > 172:
      self.actor.walk(room_pos)

  # TODO: call callbacks

proc callTrigger(self: Engine, obj: Object, trigger: HSQOBJECT) =
  if trigger.objType != OT_NULL:
    # create trigger thread
    discard sq_newthread(gVm.v, 1024)
    var thread_obj: HSQOBJECT
    sq_resetobject(thread_obj)
    if SQ_FAILED(sq_getstackobj(gVm.v, -1, thread_obj)):
      error "Couldn't get coroutine thread from stack"
      return
    sq_addref(gVm.v, thread_obj)
    sq_pop(gVm.v, 1)

    # create args
    var nParams, nfreevars: int
    sq_pushobject(gVm.v, trigger)
    discard sq_getclosureinfo(gVm.v, -1, nParams, nfreevars)
    let args = if nParams == 2: @[self.actor.table] else: @[]
    sq_pop(gVm.v, 1)
    
    let thread = newThread("Trigger", false, gVm.v, thread_obj, obj.table, trigger, args)
    info fmt"create triggerthread id: {thread.getId()} v={cast[int](thread.v.unsafeAddr)}"
    gEngine.threads.add(thread)

    # call the closure in the thread
    if not thread.call():
      error "trigger call failed"

proc updateTriggers(self: Engine) =
  if not self.actor.isNil:
    for trigger in self.room.triggers.toSeq:
      if not trigger.triggerActive and trigger.contains(self.actor.node.pos):
        info "call enter trigger " & trigger.name
        trigger.triggerActive = true
        self.callTrigger(trigger, trigger.enter)
      elif trigger.triggerActive and not trigger.contains(self.actor.node.pos):
        info "call leave trigger " & trigger.name
        trigger.triggerActive = false
        self.callTrigger(trigger, trigger.leave)

proc update(self: Engine, node: Node, elapsed: float) =
  node.update(elapsed, self.mouseState)

proc clampPos(self: Engine, at: Vec2f): Vec2f =
  let screenSize = self.room.getScreenSize()
  let x = clamp(at.x, self.bounds.left.float32, max(self.bounds.right.float32 - screenSize.x.float32, 0.0f))
  let y = clamp(at.y, self.bounds.bottom.float32, max(self.bounds.top.float32 - screenSize.y.float32, 0.0f))
  vec2(x, y)

proc cameraAt*(self: Engine, at: Vec2f) =
  ## Set the camera position to the given `at` position.
  cameraPos(self.clampPos(at))

proc walkFast(self: Engine, state = true) =
  if self.walkFastState != state:
    info "walk fast: " & $state
    self.walkFastState = state
    if not self.actor.isNil:
      sqCall(self.actor.table, "run", [state])

proc cursorText(self: Engine): string =
  if self.dlg.state == DialogState.None:
    # give can be used only on inventory and talkto to talkable objects (actors)
    result = if self.noun1.isNil or (self.hud.verb.id == VERB_GIVE and not self.noun1.inInventory()) or (self.hud.verb.id == VERB_TALKTO and not self.noun1.getFlags().hasFlag(TALKABLE)): "" else: getText(self.noun1.name)
    # add verb if not walk to or if noun1 is present
    if self.hud.verb.id > 1 or result.len > 0:
      result = if result.len > 0: fmt"{getText(self.hud.verb.text)} {result}" else: getText(self.hud.verb.text)
      if self.useFlag == ufUseWith:
        result = result & " " & getText(10000)
      elif self.useFlag == ufUseOn:
        result = result & " " & getText(10001)
      elif self.useFlag == ufUseIn:
        result = result & " " & getText(10002)
      elif self.useFlag == ufGiveTo:
        result = result & " " & getText(10003)
      if not self.noun2.isNil:
        result = result & " " & getText(self.noun2.name)

proc flashSelectableActor*(self: Engine, flash: int) =
  self.actorswitcher.flash = flash

proc follow*(self: Engine, actor: Object) =
  self.followActor = actor
  if not actor.isNil:
    let pos = actor.node.pos
    let oldRoom = self.room
    self.setRoom(actor.room)
    if oldRoom != actor.room:
      self.cameraAt(pos)

proc setCurrentActor*(self: Engine, actor: Object, userSelected = false) =
  self.actor = actor
  self.hud.actor = actor
  if self.hud.parent.isNil and not actor.isNil:
    self.screen.addChild self.hud
  elif not self.hud.parent.isNil and actor.isNil:
    self.screen.removeChild self.hud

  # call onActorSelected callbacks
  sqCall("onActorSelected", [actor.table, userSelected])
  let room = if actor.isNil: nil else: actor.room
  if not room.isNil:
    if room.table.rawExists("onActorSelected"):
      sqCall(room.table, "onActorSelected", [actor.table, userSelected])

  if not actor.isNil:
    self.follow(actor)

proc selectActor(index: int) =
  if gEngine.dlg.state == DialogState.None:
    let slot = gEngine.hud.actorSlots[index]
    if slot.selectable and not slot.actor.isNil and slot.actor.room.name != "Void":
      gEngine.setCurrentActor(slot.actor, true)

proc selectChoice(index: int) =
  gEngine.dlg.choose(index)

proc selectNextActor() =
  for i in 0..<gEngine.hud.actorSlots.len:
    let slot = gEngine.hud.actorSlots[i]
    if slot.actor == gEngine.currentActor:
      selectActor((i + 1) mod gEngine.hud.actorSlots.len)

proc selectPrevActor() =
  for i in 0..<gEngine.hud.actorSlots.len:
    let slot = gEngine.hud.actorSlots[i]
    if slot.actor == gEngine.currentActor:
      if i>0:
        selectActor((i - 1))
      else:
        selectActor(gEngine.hud.actorSlots.len - 1)

proc actorSwitcherSlot(self: Engine, slot: ActorSlot): ActorSwitcherSlot =
  let selectFunc = proc() = self.setCurrentActor(slot.actor, true)
  ActorSwitcherSlot(icon: slot.actor.getIcon(), back: slot.verbUiColors.inventoryBackground, frame: slot.verbUiColors.inventoryFrame, selectFunc: selectFunc)

proc showOptions*() =
  pushState newDlgState(newOptionsDialog(FromGame))

proc actorSwitcherSlots(self: Engine): seq[ActorSwitcherSlot] =
  if not self.actor.isNil:
    # add current actor first
    let slot = self.hud.actorSlot(self.actor)
    result.add self.actorSwitcherSlot(slot)

    # then other selectable actors
    for slot in self.hud.actorSlots:
      if slot.selectable and slot.actor != nil and slot.actor != self.actor and slot.actor.room.name != "Void":
        result.add self.actorSwitcherSlot(slot)
  
    # add gear icon
    result.add ActorSwitcherSlot(icon: "icon_gear", back: Black, frame: Gray, selectFunc: showOptions)

proc update*(self: Engine, elapsed: float) =
  self.time += elapsed

  # update camera
  let screenSize = self.room.getScreenSize()
  if not self.followActor.isNil:
    self.cameraAt(self.followActor.node.pos - vec2(screenSize.x.float32, screenSize.y.float32) / 2.0f)

  # update mouse pos
  let scrPos = winToScreen(mousePos())
  self.inputState.node.visible = self.inputState.showCursor or self.dlg.state == WaitingForChoice
  self.inputState.node.pos = scrPos

  if not self.room.isNil:
    let roomPos = self.room.screenToRoom(scrPos)
    if self.room.fullScreen == FullscreenRoom:
      if self.hud.verb.id == VERB_USE and self.useFlag != ufNone:
        self.noun2 = self.objAt(roomPos)
      elif self.hud.verb.id == VERB_GIVE:
        if self.useFlag != ufGiveTo:
          self.noun1 = self.inventoryAt(roomPos)
          self.useFlag = ufNone
          self.noun2 = nil
        else:
          self.noun2 = self.objAt(roomPos, proc (x: Object): bool = x != self.actor and x.getFlags().hasFlag(GIVEABLE))
          if not self.noun2.isNil:
            info fmt"Give '{self.noun1.key}' to '{self.noun2.key}'"
      else:
        self.noun1 = self.objAt(roomPos)
        self.useFlag = ufNone
        self.noun2 = nil
      self.inputState.setText(self.cursorText)
      # update cursor shape
      # if cursor is in the margin of the screen and if camera can move again
      # then show a left arrow or right arrow
      if scrPos.x < ScreenMargin and cameraPos().x >= 1f:
        self.inputState.setCursorShape(CursorShape.Left)
      elif scrPos.x > (ScreenWidth - ScreenMargin) and cameraPos().x < (self.room.roomSize.x.float32 - screenSize.x.float32):
        self.inputState.setCursorShape(CursorShape.Right)
      elif self.room.fullscreen == FullscreenRoom and not self.noun1.isNil:
        # if the object is a door, it has a flag indicating its direction: left, right, front, back
        let flags = self.noun1.getFlags()
        if flags.hasFlag(DOOR_LEFT):
          self.inputState.setCursorShape(CursorShape.Left)
        elif flags.hasFlag(DOOR_RIGHT):
          self.inputState.setCursorShape(CursorShape.Right)
        elif flags.hasFlag(DOOR_FRONT):
          self.inputState.setCursorShape(CursorShape.Front)
        elif flags.hasFlag(DOOR_BACK):
          self.inputState.setCursorShape(CursorShape.Back)
        else:
          self.inputState.setCursorShape(CursorShape.Normal)
      else:
        self.inputState.setCursorShape(CursorShape.Normal)

      self.hud.visible = self.inputState.inputVerbsActive and self.dlg.state == DialogState.None
      self.uiInv.visible = self.hud.visible and self.cutscene.isNil
      self.actorSwitcher.visible = self.dlg.state == DialogState.None and self.cutscene.isNil

      # call clickedAt if any button down
      if self.dlg.state == DialogState.None:
        if self.mouseState.pressed():
          if self.mouseState.click():
            self.mouseDownTime = now()
          else:
            let mouseDnDur = now() - self.mouseDownTime
            if mouseDnDur > initDuration(milliseconds = 500):
              echo "walkFast"
              self.walkFast()
        else:
          self.walkFast(false)
        if self.mouseState.pressed() or self.mouseState.pressed(mbRight):
          self.clickedAt(scrPos)
    else:
      self.hud.visible = false
      self.uiInv.visible = false
      self.noun1 = self.objAt(roomPos)
      let cText = if self.noun1.isNil: "" else: getText(self.noun1.name)
      self.inputState.setText(cText)
      self.inputState.setCursorShape(CursorShape.Normal)
      if self.mouseState.click():
        self.clickedAt(scrPos)

  # update cutscene
  if not self.cutscene.isNil:
    if self.cutscene.update(elapsed):
      self.cutscene = nil

  self.dlg.update(elapsed)

  # update nodes
  if not self.scene.isNil:
    self.update(self.scene, elapsed)
  if not self.screen.isNil:
    self.update(self.screen, elapsed)

  # update threads
  for thread in self.threads.toSeq:
    if thread.update(elapsed):
      self.threads.del self.threads.find(thread)

  # update callbacks  
  for cb in self.callbacks.toSeq:
    if cb.update(elapsed):
      let index = self.callbacks.find(cb)
      if index != -1:
        self.callbacks.del index

  # update tasks
  for t in self.tasks.toSeq:
    if t.update(elapsed):
      self.tasks.del self.tasks.find(t)

  # update audio
  self.audio.update()

  # update motors
  if not self.cameraPanTo.isNil and self.cameraPanTo.enabled:
    self.cameraPanTo.update(elapsed)

  # update actorswitcher
  self.actorswitcher.update(self.actorSwitcherSlots(), elapsed)

  # update inventory
  if self.currentActor.isNil:
    self.uiInv.update(elapsed)
  else:
    let verbUI = self.hud.actorSlot(self.currentActor).verbUiColors
    self.uiInv.update(elapsed, self.currentActor, verbUI.inventoryBackground, verbUI.verbNormal)

  # update room
  self.fade.update(elapsed)
  if not self.room.isNil:
    self.room.update(elapsed)

  # update actors
  for actor in self.actors:
    actor.update(elapsed)

  self.updateTriggers()

proc cameraPos*(self: Engine): Vec2f =
  ## Returns the camera position: the position of the middle of the screen.
  if not self.room.isNil:
    let screenSize = self.room.getScreenSize()
    result = cameraPos() + vec2(screenSize.x.float32, screenSize.y.float32) / 2.0f

proc render*(self: Engine, capture = false) =
  if not capture:
    self.frameCounter += 1
  
  # draw scene
  gfxClear(Black)
  if not self.room.isNil:
    let camSize = self.room.getScreenSize()
    camera(camSize.x.float32, camSize.y.float32)

    # update room effect
    if gShaderParams.effect != self.room.effect:
      setShaderEffect(self.room.effect)
    gShaderParams.randomValue[0] = gEngine.rand.rand(0f..1f)
    gShaderParams.timeLapse = floorMod(self.time.float32, 1000f)
    gShaderParams.iGlobalTime = gShaderParams.timeLapse
    updateShader()
    
  self.scene.draw()

  # draw screen
  let parent = self.ui.getParent
  if capture:
    self.ui.remove()
  camera(ScreenWidth, ScreenHeight)
  self.screen.draw()
  if capture:
    parent.addChild self.ui

  # draw fade
  let fade = if self.fade.enabled: self.fade.current() else: 0.0
  gfxDrawQuad(vec2f(0), camera(), rgbaf(Black, fade))

proc capture*(self: Engine, filename: string, size: Vec2i) =
  let rt = newRenderTexture(size)
  rt.use()
  self.render(true)
  rt.use(false)
  rt.capture(filename)

proc takeScreenshot() =
  gEngine.capture("screenshot.png", vec2i(ScreenWidth.int32, ScreenHeight.int32))

proc roomObjs(self: Engine, id: int): Object =
  for obj in self.roomObjs():
    if obj.id == id:
      return obj

proc soundObjVol(self: SoundId): float32 =
  let obj = gEngine.roomObjs(self.objId)
  result = 1'f32
  if not obj.isNil:
    let at = cameraPos()
    let room = gEngine.room
    result = if room != obj.room: 0'f32 else: obj.volume

    if room == obj.room:
      let width = gEngine.room.getScreenSize().x.float32
      let diff = abs(at.x - obj.node.pos.x)
      result = (1.5f - (diff / width)) / 1.5f
      if result < 0:
        result = 0
      self.pan = clamp((obj.node.pos.x - at.x) / (width / 2), -1.0, 1.0)
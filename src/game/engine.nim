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
import prefs
import motors/motor
import ../script/squtils
import ../script/flags
import ../script/vm
import ../gfx/spritesheet
import ../gfx/graphics
import ../gfx/shader
import ../gfx/color
import ../gfx/recti
import ../io/ggpackmanager
import ../io/textdb
import ../util/tween
import ../audio/audio
import ../scenegraph/node
import ../scenegraph/scene
import ../scenegraph/parallaxnode
import ../scenegraph/hud
import ../scenegraph/walkboxnode
import ../scenegraph/dialog
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
    follow*: Object
    buttons: MouseButtonMask
    mouseDownTime: DateTime
    walkFastState: bool
    walkboxNode*: WalkboxNode
    bounds*: Recti
    frameCounter*: int
    dlg*: Dialog

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
  result.hud = newHud()
  result.seedWithTime()
  result.inputState = newInputState()
  result.dlg = newDialog()
  result.screen.addChild result.inputState.node
  result.screen.addChild result.dlg
  sq_resetobject(result.defaultObj)

proc `seed=`*(self: Engine, seed: int64) =
  self.randSeed = seed
  self.rand = initRand(seed)

proc `seed`*(self: Engine): int64 =
  self.randSeed

proc `currentActor`*(self: Engine): Object =
  self.actor

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
    self.follow = actor

proc getObj(room: Room, key: string): Object =
  for layer in room.layers:
      for obj in layer.objects:
        if obj.key == key:
          return obj

proc defineRoom*(name: string, table: HSQOBJECT): Room =
  info "load room: " & name
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
        sq_resetobject(obj.table)
        result.table.getf(obj.key, obj.table)

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
          setf(obj.table, "name", obj.key)

          obj.touchable = true
          
          # adds the object to the room table
          setf(result.table, obj.name, obj.table)
          obj.setRoom(result)
          obj.setState(0, true)
        else:
          # assign an id
          obj.table.setId(newObjId())
          setf(rootTbl(gVm.v), obj.key, obj.table)
          info fmt"Create object with existing table: {obj.key} #{obj.id}"
          if obj.table.rawexists("initTouchable"):
            info fmt"initTouchable {obj.key}"
            obj.table.getf("initTouchable", obj.touchable)
          else:
            obj.touchable = true
          if obj.table.rawexists("initState"):
            info fmt"initState {obj.key}"
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
  
  # Add inventory object to root table
  for (k,v) in result.table.pairs:
    if v.objType == OT_TABLE and v.rawexists("icon"):
      info fmt"Add {k} to inventory"
      setf(rootTbl(gVm.v), k, v)
      gEngine.inventory.add Object(table: v)

  # declare the room in the root table
  result.table.setId(newRoomId())
  setf(rootTbl(gVm.v), name, result.table)

proc actorExit(self: Engine) =
  if not self.currentActor.isNil and not self.room.isNil:
    if rawExists(self.room.table, "actorExit"):
      call(self.v, self.room.table, "actorExit", [self.currentActor.table])

proc exitRoom(self: Engine, nextRoom: Room) =
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

proc enterRoom*(self: Engine, room: Room, door: Object = nil) =
  ## Called when the room is entered.
  debug fmt"call enter room function of {room.name}"

  # exit current room
  self.fade.enabled = false
  self.exitRoom(self.room)

  if not room.isNil:
    # sets the current room for scripts
    rootTbl(gVm.v).setf("currentRoom", room.table)

  self.room = room
  self.scene = room.scene
  self.room.numLights = 0
  self.bounds = rectFromMinMax(vec2(0'i32,0'i32), room.roomSize)

  # move current actor to the new room
  if not gEngine.actor.isNil:
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
  if self.room != room:
    self.fade.enabled = false
    self.exitRoom(self.room)
    if not room.isNil:
      # sets the current room for scripts
      rootTbl(gVm.v).setf("currentRoom", room.table)
    self.enterRoom(room)
    if not self.walkboxNode.isNil:
      self.walkboxNode.remove()
    self.walkboxNode = newWalkboxNode(room)
    self.scene.addChild self.walkboxNode
    self.bounds = rectFromMinMax(vec2(0'i32,0'i32), room.roomSize)

proc inInventory*(obj: Object): bool =
  gEngine.inventory.contains obj

iterator objsAt*(self: Engine, pos: Vec2f): Object =
  if not self.hud.obj.isNil:
    yield self.hud.obj
  for layer in gEngine.room.layers:
    for obj in layer.objects:
      if (obj.touchable or obj.inInventory()) and obj.node.visible and obj.objType == otNone and obj.contains(pos):
        yield obj

proc objAt*(self: Engine, pos: Vec2f): Object =
  for obj in self.objsAt(pos):
    return obj

proc objAt*(self: Engine, pos: Vec2f, pred: proc(x: Object): bool): Object =
  for obj in self.objsAt(pos):
    if pred(obj):
      return obj

proc objAt*(self: Engine, pos: Vec2f, flags: int): Object =
  self.objAt(pos, proc (x: Object): bool = x.getFlags().hasFlag(flags))

proc inventoryAt*(self: Engine, pos: Vec2f): Object =
  self.objAt(pos, proc (x: Object): bool = x.inInventory())

proc winToScreen*(self: Engine, pos: Vec2f): Vec2f =
  result = (pos / vec2f(appGetWindowSize())) * vec2(1280f, 720f)
  result = vec2(result.x, 720f - result.y)

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
  # Called after the actor has walked to the object.
  let name = if actor.isNil: "currentActor" else: actor.name
  let noun1name = if noun1.isNil: "null" else: noun1.name
  let noun2name = if noun2.isNil: "null" else: noun2.name
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
        info fmt"call {verbFuncName} on actor {noun2.key}"
        noun2.table.callFunc(handled, verbFuncName, [noun1.table])
      if not handled:
        info "call objectGive"
        call("objectGive", [noun1.table, self.actor.table, noun2.table])
        self.actor.giveTo(noun2, noun1)
        self.hud.updateInventory()
    return

  if noun2.isNil:
    call(noun1.table, verbFuncName)
  else:
    call(noun1.table, verbFuncName, [noun2.table])

  # TODO: finish this

  info "reset nouns"
  gEngine.noun1 = nil
  gEngine.noun2 = nil
  gEngine.useFlag = ufNone

import actor

proc preWalk(self: Engine, actor: Object, verbId: VerbId, noun1: Object; noun2: Object): bool =
  var n2Table: HSQOBJECT
  if not noun2.isNil:
    n2Table = noun2.table
  else:
    sq_resetobject(n2Table)
  if actor.table.rawexists("actorPreWalk"):
    actor.table.sqCallFunc(result, "actorPreWalk", [verbId.int32, noun1.table, n2Table])
  if not result:
    let funcName = if noun1.id.isActor: "actorPreWalk" else: "objectPreWalk"
    if rawexists(noun1.table, funcName):
      noun1.table.sqCallFunc(result, funcName, [verbId.int32, noun1.table, n2Table])

proc execSentence*(self: Engine, actor: Object, verbId: VerbId, noun1: Object; noun2: Object = nil): bool =
  ## Called to execute a sentence and, if needed, start the actor walking.
  ## If `actor` is `null` then the selectedActor is assumed.
  let name = if actor.isNil: "currentActor" else: actor.name
  let noun1name = if noun1.isNil: "null" else: noun1.name
  let noun2name = if noun2.isNil: "null" else: noun2.name
  info fmt"exec({name},{verbId},{noun1name},{noun2name})"
  var actor = if actor.isNil: gEngine.currentActor else: actor
  if verbId <= 0 and verbId > 13 or noun1.isNil:
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
  if self.room.table.rawexists("clickedAt"):
    info "clickedAt " & $[roomPos.x, roomPos.y]
    self.room.table.callFunc(result, "clickedAt", [roomPos.x, roomPos.y])
    if not result:
      if not self.actor.isNil and self.actor.table.rawexists("clickedAt"):
        self.actor.table.callFunc(result, "clickedAt", [roomPos.x, roomPos.y])

proc getVerb(self: Engine, id: int): Verb =
  if not self.actor.isNil:
    for verb in self.hud.actorSlot(self.actor).verbs:
      if verb.id == id:
        return verb  

proc clickedAt(self: Engine, scrPos: Vec2f, btns: MouseButtonMask) =
  # TODO: WIP
  if not self.room.isNil and self.inputState.inputActive:
    let roomPos = self.room.screenToRoom(scrPos)
    let obj = self.objAt(roomPos)

    if mbLeft in btns and mbLeft notin self.buttons:
      # button left: execute selected verb
      var handled = false
      if not obj.isNil:
        let verb = self.hud.verb
        if obj.table.exists(verb.fun) or verb.id == VERB_GIVE:
          handled = self.execSentence(nil, verb.id, self.noun1, self.noun2)
      if not handled and not self.clickedAtHandled(roomPos):
        if not self.actor.isNil and scrPos.y > 172:
          self.actor.walk(room_pos)
          self.hud.verb = self.getVerb(VERB_WALKTO)
        # Just clicking on the ground
        self.cancelSentence(self.actor)
    elif mbRight in btns and mbRight notin self.buttons:
      # button right: execute default verb
      if not obj.isNil and obj.table.rawexists("defaultVerb"):
        var defVerbId: int
        obj.table.getf("defaultVerb", defVerbId)
        let verbName = self.hud.actorSlot(self.actor).verb(defVerbId.int).fun
        if obj.table.rawexists(verbName):
          discard self.execSentence(nil, defVerbId, self.noun1, self.noun2)
    elif self.walkFastState and mbLeft in btns and not self.actor.isNil and scrPos.y > 172:
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

proc update*(self: Engine, node: Node, elapsed: float) =
  let mouseState = mouseBtns()
  let isMouseDn = mbLeft in mouseState and mbLeft notin self.buttons
  if node.buttons.len > 0:
    let scrPos = self.winToScreen(mousePos())
    for btn in node.buttons.toSeq:
      # mouse inside button ?
      if node.getRect().contains(scrPos):
        # enter button ?
        if not btn.inside:
          btn.inside = true
          btn.callback(node, Enter, scrPos, btn.tag)
        # mouse down on button ?
        elif not btn.down and isMouseDn:
          btn.down = true
          btn.callback(node, Down, scrPos, btn.tag)
        # mouse up on button ?
        elif btn.down and mbLeft notin mouseState:
          btn.down = false
          btn.callback(node, Up, scrPos, btn.tag)
      # mouse leave button ?
      elif btn.inside:
        btn.inside = false
        btn.callback(node, Leave, scrPos, btn.tag)
      else:
        btn.down = false

  if not node.shakeMotor.isNil and node.shakeMotor.enabled():
    node.shakeMotor.update(elapsed)

  for node in node.children.toSeq:
    self.update(node, elapsed)

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

proc update(self: Engine) =
  let elapsed = tmpPrefs().gameSpeedFactor / 60'f32
  self.time += elapsed

  # update camera
  let screenSize = gEngine.room.getScreenSize()
  if not self.follow.isNil:
    self.cameraAt(self.follow.node.pos - vec2(screenSize.x.float32, screenSize.y.float32) / 2.0f)

  # update mouse pos
  let scrPos = self.winToScreen(mousePos())
  self.inputState.node.visible = self.inputState.showCursor
  self.inputState.node.pos = scrPos
  if not self.room.isNil:
    let roomPos = self.room.screenToRoom(scrPos)
    if self.hud.verb.id == VERB_USE and self.useFlag != ufNone:
      self.noun2 = self.objAt(roomPos)
    elif self.hud.verb.id == VERB_GIVE:
      if self.useFlag != ufGiveTo:
        self.noun1 = self.inventoryAt(roomPos)
        self.useFlag = ufNone
        self.noun2 = nil
      else:
        self.noun2 = self.objAt(roomPos, GIVEABLE)
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
    elif not self.noun1.isNil:
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

  self.hud.visible = self.inputState.inputVerbsActive and not self.room.isNil and self.room.fullScreen != 1 and self.dlg.state == DialogState.None

  # call clickedAt if any button down
  let btns = mouseBtns()
  if self.dlg.state == DialogState.None:
    if mbLeft in btns:
      if mbLeft notin self.buttons:
        self.mouseDownTime = now()
      else:
        let mouseDnDur = now() - self.mouseDownTime
        if mouseDnDur > initDuration(milliseconds = 500):
          self.walkFast()
    else:
      self.walkFast(false)
    if btns.len > 0:
      self.clickedAt(scrPos, btns)

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
      self.callbacks.del self.callbacks.find(cb)

  # update tasks
  for t in self.tasks.toSeq:
    if t.update(elapsed):
      self.tasks.del self.tasks.find(t)

  # update audio
  self.audio.update()

  # update motors
  if not self.cameraPanTo.isNil and self.cameraPanTo.enabled:
    self.cameraPanTo.update(elapsed)

  # update room
  self.fade.update(elapsed)
  if not self.room.isNil:
    self.room.update(elapsed)

  # update actors
  for actor in self.actors:
    actor.update(elapsed)

  self.updateTriggers()
  self.buttons = btns

proc cameraPos*(self: Engine): Vec2f =
  ## Returns the camera position: the position of the middle of the screen.
  if not self.room.isNil:
    let screenSize = self.room.getScreenSize()
    result = cameraPos() + vec2(screenSize.x.float32, screenSize.y.float32) / 2.0f

proc render*(self: Engine) =
  self.update()
  self.frameCounter += 1
  
  # draw scene
  gfxClear(Gray)
  if not self.room.isNil:
    var camSize = self.room.getScreenSize()
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
  camera(ScreenWidth, ScreenHeight)
  self.screen.draw()

  # draw fade
  let fade = if self.fade.enabled: self.fade.current() else: 0.0
  gfxDrawQuad(vec2f(0), camera(), rgbaf(Black, fade))

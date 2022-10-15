import glm
import std/os
import std/json
import std/times
import std/tables
import std/strformat
import std/strutils
import std/logging
import std/algorithm
import sqnim
import nimyggpack
import ../script/squtils
import ../script/vm
import ../io/ggpackmanager
import ../scenegraph/dialog
import ../scenegraph/node
import ../scenegraph/hud
import ../scenegraph/actorswitcher
import ../game/callback
import ../game/prefs
import ../game/room
import ../game/actor
import ../game/engine
import ../game/ids
import ../game/gameloader
import ../game/inputstate
import ../gfx/color
import ../util/jsonutil
import ../util/utils

const
  ThumbnailSize = vec2i(320'i32, 180'i32)

proc actor(key: string): Object =
  for a in gEngine.actors:
    if a.key == key:
      return a

proc loadGameScene(json: JsonNode) =
  var mode: set[ActorSlotSelectableMode]
  if json["actorsSelectable"].getInt() != 0:
    mode.incl asOn
  if json["actorsTempUnselectable"].getInt() != 0:
    mode.incl asTemporaryUnselectable
  gEngine.actorswitcher.mode = mode
  tmpPrefs().forceTalkieText = json["forceTalkieText"].getInt() != 0
  for i in 0..<json["selectableActors"].len:
    let jSelectableActor =json["selectableActors"][i]
    let actor = if jSelectableActor.hasKey("_actorKey"): actor(jSelectableActor["_actorKey"].getStr()) else: nil
    gEngine.hud.actorSlots[i].actor = actor
    gEngine.hud.actorSlots[i].selectable = jSelectableActor["selectable"].getInt() != 0

proc parseMode(mode: char): DialogConditionMode =
  case mode:
  of '?':
    result = Once
  of '#':
    result = ShowOnce
  of '&':
    result = OnceEver
  of '$':
    result = ShowOnceEver
  of '^':
    result = TempOnce
  else:
    warn fmt"Invalid dialog condition mode: {mode}"

proc parseState(dialog: string): DialogConditionState =
  var dialogName: string
  var i = 1
  while i < dialog.len and not isDigit(dialog[i]):
    dialogName.add dialog[i]
    inc i

  while not gGGPackMgr.assetExists(dialogName & ".byack") and i < dialog.len:
    dialogName.add dialog[i]
    inc i

  var num: string
  while i < dialog.len and isDigit(dialog[i]):
    num.add dialog[i]
    inc i

  result.mode = parseMode(dialog[0])
  result.dialog = dialogName
  result.line = parseInt(num)
  result.actorKey = dialog.substr(i)

proc loadDialog(json: JsonNode) =
  info "loadDialog"
  gEngine.dlg.states.setLen 0
  for property in json.pairs:
    let dialog = property.key
    # dialog format: mode dialog number actor
    # example: #ChetAgentStreetDialog14reyes
    # mode:
    # ?: once
    # #: showonce
    # &: onceever
    # $: showonceever
    # ^: temponce
    let state = parseState(dialog)
    gEngine.dlg.states.add(state)
    # TODO: what to do with this dialog value ?
    # let value = property.second.getInt()

proc obj(key: string): Object =
  for room in gEngine.rooms:
    for layer in room.layers:
      for o in layer.objects:
        if o.key == key:
          return o

proc obj(room: Room, key: string): Object =
  for layer in room.layers:
    for o in layer.objects:
      if o.key == key:
        return o

proc room(name: string): Room =
  for room in gEngine.rooms:
    if room.name == name:
      return room

proc toSquirrel(json: JsonNode, obj: var HSQObject) =
  let top = sq_gettop(gVm.v)
  sq_resetobject(obj)
  case json.kind:
  of JString:
    push(gVm.v, json.getStr())
    discard get(gVm.v, -1, obj)
  of JInt:
    push(gVm.v, json.getInt())
    discard get(gVm.v, -1, obj)
  of JBool:
    push(gVm.v, json.getBool())
    discard get(gVm.v, -1, obj)
  of JFloat:
    push(gVm.v, json.getFloat())
    discard get(gVm.v, -1, obj)
  of JNull:
    discard
  of JArray:
    sq_newarray(gVm.v, 0)
    for j in json.getElems():
      var tmp: HSQOBJECT
      toSquirrel(j, tmp)
      push(gVm.v, tmp)
      discard sq_arrayappend(gVm.v, -2)
    discard get(gVm.v, -1, obj)
  of JObject:
    # check if it's a reference to an actor
    if json.hasKey "_actorKey":
      obj = actor(json["_actorKey"].getStr).table
    elif json.hasKey "_roomKey":
      let roomName = json["_roomKey"].getStr
      if json.hasKey "_objectKey":
        let objName = json["_objectKey"].getStr
        let room = room(roomName)
        if room.isNil:
          warn fmt"room with key={roomName} not found"
        else:
          let o = obj(room, objName)
          if o.isNil:
            warn fmt"room object with key={roomName}/{objName} not found"
          else:
            obj = o.table
      else:
        let room = room(roomName)
        if room.isNil:
          warn fmt"room with key={roomName} not found"
        else:
          obj = room.table
    elif json.hasKey "_objectKey":
      let objName = json["_objectKey"].getStr
      let o = obj(objName)
      if o.isNil:
        warn fmt"object with key={objName} not found"
      else:
        obj = o.table
    else:
      sq_newtable(gVm.v)
      for (k, v) in json.getFields().pairs:
        push(gVm.v, k)
        var tmp: HSQOBJECT
        toSquirrel(v, tmp)
        push(gVm.v, tmp)
        discard sq_newslot(gVm.v, -3, SQFalse)
      discard get(gVm.v, -1, obj)
  sq_addref(gVm.v, obj)
  sq_settop(gVm.v, top)

proc loadCallbacks(json: JsonNode) =
  info "loadCallbacks"
  gEngine.callbacks.setLen 0
  if json["callbacks"].kind != JNull:
    for callBackHash in json["callbacks"]:
      let
        id = callBackHash["guid"].getInt()
        time = callBackHash["time"].getInt().float / 1000f
        name = callBackHash["function"].getStr()
      if callBackHash.hasKey "param":
        var arg: HSQOBJECT
        toSquirrel(callBackHash["param"], arg)
        var args: seq[HSQOBJECT]
        for a in arg.mitems:
          args.add a
        gEngine.callbacks.add newCallback(id, time, name, args)
      else:
        gEngine.callbacks.add newCallback(id, time, name, @[])
  setCallbackId(json["nextGuid"].getInt())

proc loadGlobals(json: JsonNode) =
  info "loadGlobals"
  var g: HSQOBJECT
  getf("g", g)
  assert g.objType == OT_TABLE
  for (k, v) in json.pairs:
    debug "load globals '" & k & "': " & $v
    var tmp: HSQOBJECT
    toSquirrel(v, tmp)
    sq_addref(gVm.v, tmp)
    setf(g, k, tmp)

proc setRoom(name: string) =
  gEngine.setRoom(room(name))

proc setActor(key: string) =
  for actor in gEngine.actors:
    if actor.key == key:
      gEngine.setCurrentActor(actor, false)
      return

proc setAnimations(actor: Object, anims: JsonNode) =
  let headAnim = anims[0].getStr()
  let standAnim = anims[9].getStr()[0..^7]
  let walkAnim = anims[11].getStr()[0..^7]
  let reachAnim = anims[15].getStr()[0..^11]
  actor.setAnimationNames(headAnim, standAnim, walkAnim, reachAnim)

proc loadActor(actor: Object, json: JsonNode) =
  var touchable = true
  if json.hasKey("_untouchable"):
    touchable = json["_untouchable"].getInt() == 0
  actor.touchable = touchable
  var hidden = false
  if json.hasKey("_hidden"):
    hidden = json["_hidden"].getInt() == 1
  actor.node.visible = not hidden
  for (k, v) in json.pairs:
    case k:
    of "_animations":
      setAnimations(actor, v)
    of "_pos":
      actor.node.pos = vec2f(parseVec2i(v.getStr()))
    of "_costume":
      var sheet: string
      if json.hasKey "_costumeSheet":
        sheet = json["_costumeSheet"].getStr()
      actor.setCostume(v.getStr, sheet)
    of "_costumeSheet":
      discard
    of "_color":
      actor.node.color = rgba(v.getInt)
      actor.node.alpha = rgba(v.getInt).a
    of "_dir":
      actor.setFacing(v.getInt().Facing)
    of "_lockFacing":
      actor.lockFacing(v.getInt())
    of "_useDir":
      actor.useDir = v.getInt().Direction
    of "_usePos":
      actor.usePos = vec2f(parseVec2i(v.getStr()))
    of "_offset":
      actor.node.offset = vec2f(parseVec2i(v.getStr()))
    of "_renderOffset":
      actor.node.renderOffset = vec2f(parseVec2i(v.getStr()))
    of "_roomKey":
      actor.setRoom(room(v.getStr))
    of "_hidden", "_untouchable":
      discard
    of "_volume":
      actor.volume = v.getFloat()
    elif not k.startsWith('_'):
      var tmp: HSQOBJECT
      toSquirrel(v, tmp)
      if actor.table.rawexists(k):
        actor.table.setf(k, tmp)
      else:
        actor.table.newf(k, tmp)
    else:
      warn fmt"load actor: key '{k}' is unknown: {v}"

  if actor.table.rawexists("postLoad"):
    sqCall(actor.table, "postLoad", [])

proc loadInventory(json: JsonNode) =
  if json.kind != JNull:
    let jSlots = json["slots"]
    for i in 0..<gEngine.hud.actorSlots.len:
      let actor = gEngine.hud.actorSlots[i].actor
      if not actor.isNil:
        actor.inventory.setLen 0
        let jSlot = jSlots[i]
        if jSlot.hasKey "objects":
          if jSlot["objects"].kind != JNull:
            for jObj in jSlot["objects"]:
              let obj = obj(jObj.getStr())
              if obj.isNil:
                warn fmt"inventory obj '{jObj.getStr()}' not found"
              else:
                actor.pickupObject obj
          # TODO: "jiggle"
        actor.inventoryOffset = jSlot["scroll"].getInt()

proc loadActors(json: JsonNode) =
  for actor in gEngine.actors:
    if actor.key.len > 0:
      loadActor(actor, json[actor.key])

proc loadObj(obj: Object, json: JsonNode) =
  var state: int
  if json.hasKey("_state"):
    state = json["_state"].getInt
  if not obj.node.isNil:
    obj.setState(state, true)
  else:
    warn fmt"obj '{obj.key}' has no node !"
  var touchable = true
  if json.hasKey("_touchable"):
    touchable = json["_touchable"].getInt == 1
  obj.touchable = touchable
  var hidden = false
  if json.hasKey("_hidden"):
    hidden = json["_hidden"].getInt == 1
  obj.node.visible = not hidden

  for (k, v) in json.pairs:
    case k:
    of "_state", "_touchable", "_hidden":
      discard
    of "_pos":
      obj.node.pos = vec2f(parseVec2i(v.getStr()))
    of "_rotation":
      obj.node.rotation = v.getFloat()
    of "_dir":
      obj.setFacing(v.getInt().Facing)
    of "_useDir":
      obj.useDir = v.getInt().Direction
    of "_usePos":
      obj.usePos = vec2f(parseVec2i(v.getStr()))
    of "_offset":
      obj.node.offset = vec2f(parseVec2i(v.getStr()))
    of "_renderOffset":
      obj.node.renderOffset = vec2f(parseVec2i(v.getStr()))
    of "_roomKey":
      obj.setRoom(room(v.getStr))
    elif not k.startsWith('_'):
      var tmp: HSQOBJECT
      toSquirrel(v, tmp)
      if obj.table.rawexists(k):
        obj.table.setf(k, tmp)
      else:
        obj.table.newf(k, tmp)
    else:
      warn fmt"load object: key '{k}' is unknown"

  if obj.table.rawexists("postLoad"):
    sqCall(obj.table, "postLoad", [])

proc loadObjects(json: JsonNode) =
  for (k, v) in json.pairs:
    let o = obj(k)
    if not o.isNil:
      loadObj(obj(k), v)
    else:
      warn fmt"object '{k}' not found"

proc loadPseudoObjects(room: Room, json: JsonNode) =
  for (k, v) in json.pairs:
    let o = obj(room, k)
    if o.isNil:
      warn fmt"load: room '{room.name}' object '{k}' not loaded because it has not been found"
    else:
      loadObj(o, v)

proc loadRoom(room: Room, json: JsonNode) =
  for (k, v) in json.pairs:
    case k:
    of "_pseudoObjects":
      loadPseudoObjects(room, v)
    else:
      if not k.startsWith('_'):
        let o = obj(room, k)
        if o.isNil:
          var tmp: HSQOBJECT
          toSquirrel(v, tmp)
          if room.table.rawexists(k):
            room.table.setf(k, tmp)
          else:
            room.table.newf(k, tmp)
        else:
          loadObj(o, v)
      else:
        warn fmt"Load room: key '{k}' is unknown"

  if room.table.rawexists("postLoad"):
    sqCall(room.table, "postLoad", [])

proc loadRooms(json: JsonNode) =
  for (k, v) in json.pairs:
    loadRoom(room(k), v)

proc loadGame(json: JsonNode) =
  let version = json["version"].getInt()
  if version != 2:
    error fmt"Cannot load savegame version {version}"
    return

  sqCall("preLoad", [])
  info fmt"top gameScene: {sq_gettop(gVm.v)}"
  loadGameScene(json["gameScene"])
  info fmt"top dialog: {sq_gettop(gVm.v)}"
  loadDialog(json["dialog"])
  info fmt"top callbacks: {sq_gettop(gVm.v)}"
  loadCallbacks(json["callbacks"])
  info fmt"top globals: {sq_gettop(gVm.v)}"
  loadGlobals(json["globals"])
  info fmt"top actors: {sq_gettop(gVm.v)}"
  loadActors(json["actors"])
  info fmt"top inventory: {sq_gettop(gVm.v)}"
  loadInventory(json["inventory"])
  info fmt"top rooms: {sq_gettop(gVm.v)}"
  loadRooms(json["rooms"])
  info fmt"top gameTime: {sq_gettop(gVm.v)}"
  gEngine.time = json["gameTime"].getFloat
  gEngine.inputState.setState(json["inputState"].getInt().InputStateFlag)
  loadObjects(json["objects"])
  info fmt"top selectedActor: {sq_gettop(gVm.v)}"
  setActor(json["selectedActor"].getStr())
  info fmt"top currentRoom: {sq_gettop(gVm.v)}"
  setRoom(json["currentRoom"].getStr())
  info fmt"top SAVEBUILD: {sq_gettop(gVm.v)}"

  setf(rootTbl(gVm.v), "SAVEBUILD", json["savebuild"].getInt())

  sqCall("postLoad", [])

type
  EngineGameLoader = ref object of GameLoader

method load(self: EngineGameLoader, json: JsonNode) =
  writeFile("load.json", json.pretty(2))
  loadGame(json)

proc saveGame*(path: string)

method save(self: EngineGameLoader, index: int) =
  let path = fmt"Savegame{index+1}.save"
  saveGame(path)

proc newEngineGameLoader*(): GameLoader =
  EngineGameLoader()

# SAVEGAME

proc cmpKey(x,y: tuple[key: string, val: JsonNode]): int = cmp(x.key, y.key)

proc tojson(obj: var HSQOBJECT, checkId: bool, skipObj = false, pseudo = false): JsonNode =
  let rootTbl = rootTbl(gVm.v)
  case obj.objType:
  of OT_INTEGER:
    result = newJInt(sq_objtointeger(obj))
  of OT_FLOAT:
    result = newJFloat(sq_objtofloat(obj))
  of OT_STRING:
    result = newJString($sq_objtostring(obj))
  of OT_NULL:
    result = newJNull()
  of OT_ARRAY:
    result = newJArray()
    for item in obj.mitems:
      result.add tojson(item, true)
  of OT_TABLE:
    result = newJObject()
    if checkId:
      let id = obj.getId()
      if id.isActor():
        let actor = actor(id)
        result["_actorKey"] = newJString(actor.key)
        return result
      elif id.isObject():
        let obj = obj(id)
        if obj.isNil:
          return newJNull()
        result["_objectKey"] = newJString(obj.key)
        if not obj.room.isNil and obj.room.pseudo:
          result["_roomKey"] = newJString(obj.room.name)
        return result
      elif id.isRoom():
        let room = room(id)
        result["_roomKey"] = newJString(obj.room.name)
        return result

    for (k, v) in obj.mpairs:
      if k.len > 0 and k[0] != '_':
        if not (skipObj and v.getId().isObject() and (pseudo or rootTbl.rawexists(k))):
          let json = tojson(v, true)
          if not json.isNil:
            result[k] = json
    result.fields.sort(cmpKey)
  else:
    discard

proc tostr(pos: Vec2f): string =
  let p = vec2i(pos)
  fmt"{{{p.x},{p.y}}}"

proc toint(c: Color) : int =
  let r = (c.r * 255f).int
  let g = (c.g * 255f).int
  let b = (c.b * 255f).int
  let a = (c.a * 255f).int
  (r shl 16) or (g shl 8) or b or (a shl 24)

proc hasCustomAnim(actor: Object): bool =
  if actor.facingMap.len > 0:
    return true
  if actor.animNames.len > 0:
    for name in [HeadAnimName, StandAnimName, WalkAnimName, ReachAnimName]:
      if actor.animNames.hasKey(name) and actor.animNames[name] != name:
        return true

proc getFacingMap(actor: Object): Table[string, string] =
  if actor.animNames.len > 0:
    return actor.animNames
  return {HeadAnimName: HeadAnimName, StandAnimName: StandAnimName, WalkAnimName: WalkAnimName, ReachAnimName: ReachAnimName}.toTable

proc getCustomAnim(facingMap: Table[string, string], name: string): string =
  result = if facingMap.hasKey(name): facingMap[name] else: name

proc getCustomAnims(actor: Object): JsonNode =
  result = newJArray()
  let facingMap = actor.getFacingMap()
  # add head anims
  result.add newJString(facingMap.getCustomAnim(HeadAnimName))
  for i in 1..6:
    result.add newJString(facingMap.getCustomAnim(HeadAnimName) & $i)
  # add stand anims
  result.add newJString(facingMap.getCustomAnim(StandAnimName) & "_front")
  result.add newJString(facingMap.getCustomAnim(StandAnimName) & "_back")
  result.add newJString(facingMap.getCustomAnim(StandAnimName) & "_left")
  result.add newJString(facingMap.getCustomAnim(StandAnimName) & "_right")
  # add walk anims
  result.add newJString(facingMap.getCustomAnim(WalkAnimName) & "_front")
  result.add newJString(facingMap.getCustomAnim(WalkAnimName) & "_back")
  result.add newJString(facingMap.getCustomAnim(WalkAnimName) & "_right")
  result.add newJString(facingMap.getCustomAnim(WalkAnimName) & "_right")
  # add reach anims
  for dir in ["_front", "_back", "_right", "_right"]:
    result.add newJString(facingMap.getCustomAnim(ReachAnimName) & "_low" & dir)
    result.add newJString(facingMap.getCustomAnim(ReachAnimName) & "_med" & dir)
    result.add newJString(facingMap.getCustomAnim(ReachAnimName) & "_high" & dir)

proc createJActor(actor: Object): JsonNode =
  result = tojson(actor.table, false)
  if actor.node.color != White:
    result["_color"] = newJInt(cast[int32](rgbaf(actor.node.color, actor.node.alpha).toint))
  if actor.hasCustomAnim():
    result["_animations"] = actor.getCustomAnims()
  result["_costume"] = newJString(changeFileExt(actor.costumeName, ""))
  result["_dir"] = newJInt(actor.facing.int)
  result["_lockFacing"] = newJInt(actor.facingLockValue)
  result["_pos"] = newJString(actor.node.pos.tostr)
  if actor.useDir != dNone:
    result["_useDir"] = newJInt(actor.useDir.int)
  if actor.usePos != vec2(0f, 0f):
    result["_usePos"] = newJString(actor.usePos.tostr)
  if actor.node.renderOffset != vec2(0f, 45f):
    result["_renderOffset"] = newJString(actor.node.renderOffset.tostr)
  if actor.costumeSheet.len > 0:
    result["_costumeSheet"] = newJString(actor.costumeSheet)
  if not actor.room.isNil:
    result["_roomKey"] = newJString(actor.room.name)
  if not actor.touchable and actor.node.visible:
    result["_untouchable"] = newJInt(1)
  if not actor.node.visible:
    result["_hidden"] = newJInt(1)
  if actor.volume != 0f:
    result["_volume"] = newJFloat(actor.volume)
  result.fields.sort(cmpKey)

proc createJActors(): JsonNode =
  result = newJObject()
  for actor in gEngine.actors:
    if actor.key != "":
      result[actor.key] = createJActor(actor)
  result.fields.sort(cmpKey)

proc createJCallback(callback: Callback): JsonNode =
  result = newJObject()
  result["function"] = newJString(callback.name)
  result["guid"] = newJInt(callback.id)
  result["time"] = newJFloat(max(0, callback.duration - callback.elapsed))
  let jArgs = newJArray()
  for arg in callback.args.mitems:
    jArgs.add tojson(arg, false)
  if jArgs.len > 0:
    result["param"] = jArgs

proc createJCallbackArray(): JsonNode =
  result = newJArray()
  for callback in gEngine.callbacks:
    result.add createJCallback(callback)

proc createJCallbacks(): JsonNode =
  result = newJObject()
  result["callbacks"] = createJCallbackArray()
  result["nextGuid"] = newJInt(getCallbackId())

proc createJRoomKey(room: Room): JsonNode =
  newJString(if room.isNil: "Void" else: room.name)

proc createJDlgStateKey(state: DialogConditionState): string =
  var s: string
  case state.mode:
  of OnceEver:
    s = "&"
  of ShowOnce:
    s = "#"
  of Once:
    s = "?"
  of ShowOnceEver:
    s = "$"
  else:
    discard
  fmt"{s}{state.dialog}{state.line}{state.actorKey}"

proc createJDialog(): JsonNode =
  result = newJObject()
  for state in gEngine.dlg.states:
    if state.mode !=  TempOnce:
      # TODO: value should be 1 or another value ?
      result[createJDlgStateKey(state)] = newJInt(if state.mode == ShowOnce: 2 else: 1)

proc createJEasyMode(): JsonNode =
  var g: HSQOBJECT
  getf("g", g)
  var easyMode: int
  getf(g, "easy_mode", easyMode)
  result = newJInt(easyMode)

proc toint(b: bool): int =
  if b: 1 else: 0

proc createJSelectableActor(slot: ActorSlot): JsonNode =
  result = newJObject()
  if not slot.actor.isNil:
    result["_actorKey"] = newJString(slot.actor.key)
  result["selectable"] = newJInt(slot.selectable.toint)

proc createJSelectableActors(): JsonNode =
  result = newJArray()
  for slot in gEngine.hud.actorSlots:
    result.add createJSelectableActor(slot)

proc createJGameScene(): JsonNode =
  let actorsSelectable = asOn in gEngine.actorswitcher.mode
  let actorsTempUnselectable = asTemporaryUnselectable in gEngine.actorswitcher.mode
  result = newJObject()
  result["actorsSelectable"] = newJInt(actorsSelectable.toint)
  result["actorsTempUnselectable"] = newJInt(actorsTempUnselectable.toint)
  result["forceTalkieText"] = newJInt(tmpPrefs().forceTalkieText.toint)
  result["selectableActors"] = createJSelectableActors()

proc createJGlobals(): JsonNode =
  var g: HSQOBJECT
  getf("g", g)
  result = tojson(g, false)
  result.fields.sort(cmpKey)

proc createJInputState(): JsonNode =
  newJInt(gEngine.inputState.getState().int)

proc createJInventory(slot: ActorSlot): JsonNode =
  result = newJObject()
  if slot.actor.isNil:
    result["scroll"] = newJInt(0)
  else:
    let objKeys = newJArray()
    let jiggleArray = newJArray()
    var anyJiggle: bool
    for obj in slot.actor.inventory:
      # TODO: jiggle
      #let jiggle = obj.getJiggle()
      let jiggle = false
      if jiggle:
        anyJiggle = true
      jiggleArray.add newJInt(jiggle.toint)
      objKeys.add newJString(obj.key)

    if objKeys.len > 0:
      result["objects"] = objKeys
    result["scroll"] = newJInt(slot.actor.inventoryOffset)
    if anyJiggle:
      result["jiggle"] = jiggleArray

proc createJInventory(): JsonNode =
  let slots = newJArray()
  for slot in gEngine.hud.actorSlots:
    slots.add createJInventory(slot)
  result = newJObject()
  result["slots"] = slots

proc createJObject(table: var HSQOBJECT, obj: Object): JsonNode =
  result = tojson(table, false)
  if not obj.isNil:
    if not obj.node.visible:
      result["_hidden"] = newJInt(1)
    if obj.state != 0:
      result["_state"] = newJInt(obj.state)
    if obj.node.visible and not obj.touchable:
      result["_touchable"] = newJInt(0)
    if obj.node.offset != Vec2f():
      result["_offset"] = newJString(obj.node.offset.tostr)
  result.fields.sort(cmpKey)

proc createJObjects(): JsonNode =
  result = newJObject()
  for (k, v) in rootTbl(gVm.v).mpairs:
    if v.getId().isObject():
      let obj = obj(v)
      if obj.isNil or obj.objType == otNone:
        #info fmt"obj: createJObject({k})"
        result[k] = createJObject(v, obj)
  result.fields.sort(cmpKey)

proc createJPseudoObjects(room: Room): JsonNode =
  result = newJObject()
  for (k, v) in room.table.mpairs:
    if v.getId().isObject():
      let obj = obj(v)
      #info fmt"pseudoObj: createJObject({k})"
      result[k] = createJObject(v, obj)
  result.fields.sort(cmpKey)

proc createJRoom(room: Room): JsonNode =
  result = tojson(room.table, false, true, room.pseudo)
  if room.pseudo:
    result["_pseudoObjects"] = createJPseudoObjects(room)
  result.fields.sort(cmpKey)

proc createJRooms(): JsonNode =
  result = newJObject()
  for room in gEngine.rooms:
    if not room.isNil:
      result[room.name] = createJRoom(room)
  result.fields.sort(cmpKey)

proc createJActorKey(actor: Object): JsonNode =
  newJString(if actor.isNil: "" else: actor.key)

proc createSaveGame(): Savegame =
  let t = getTime()
  let json = newJObject()
  json["actors"] = createJActors()
  json["callbacks"] = createJCallbacks()
  json["currentRoom"] = createJRoomKey(gEngine.room)
  json["dialog"] = createJDialog()
  json["easy_mode"] = createJEasyMode()
  json["gameGUID"] = newJString("")
  json["gameScene"] = createJGameScene()
  json["gameTime"] = newJFloat(gEngine.time)
  json["globals"] = createJGlobals()
  json["inputState"] = createJInputState()
  json["inventory"] = createJInventory()
  json["objects"] = createJObjects()
  json["rooms"] = createJRooms()
  json["savebuild"] = newJInt(958)
  json["savetime"] = newJInt(t.toUnix)
  json["selectedActor"] = createJActorKey(gEngine.actor)
  json["version"] = newJInt(2)
  Savegame(data: json, time: t)

proc saveGame*(path: string) =
  call("preSave")
  let data = createSaveGame()
  let thumbnail = changeFileExt(path, ".png")
  let jsonFile = changeFileExt(path, ".json")
  writeFile(jsonFile, pretty(data.data))
  gEngine.capture(thumbnail, ThumbnailSize)
  saveSaveGame(path, data)
  call("postSave")
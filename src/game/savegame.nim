import glm
import std/json
import std/tables
import std/strformat
import std/strutils
import std/logging
import sqnim
import ../script/squtils
import ../script/vm
import ../io/ggpackmanager
import ../scenegraph/dialog
import ../game/callback
import ../game/room
import ../game/actor
import ../game/engine
import ../game/ids
import ../game/gameloader
import ../game/inputstate
import ../scenegraph/node
import ../gfx/color
import ../util/jsonutil

proc loadGameScene(json: JsonNode) =
  warn("loadGameScene not implemented")
  discard
  # let actorsSelectable = json["actorsSelectable"].getInt()
  # let actorsTempUnselectable = json["actorsTempUnselectable"].getInt()
  # let mode = if actorsSelectable: ActorSlotSelectableMode.On else: ActorSlotSelectableMode.Off
  # if actorsTempUnselectable:
  #   mode |= ActorSlotSelectableMode::TemporaryUnselectable;
  # setActorSlotSelectable(mode)
  # let forceTalkieText = json["forceTalkieText"].getInt() != 0
  # setTempPreference(TempPreferenceNames::ForceTalkieText, forceTalkieText)
  # for selectableActor in json["selectableActors"]:
  #   let actor = getActor(selectableActor[actorKey].getString())
  #   let selectable = selectableActor["selectable"].getInt() != 0
  #   actorSlotSelectable(pActor, selectable)

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
  debug "parseState " & dialog
  
  var dialogName: string
  var i = 1
  while i < dialog.len and not isDigit(dialog[i]):
    dialogName.add dialog[i]
    inc i
  
  debug "parseState dialogName:" & dialogName
  while not gGGPackMgr.assetExists(dialogName & ".byack") and i < dialog.len:
    dialogName.add dialog[i]
    inc i

  debug "parseState dialogName:" & dialogName

  var num: string
  while i < dialog.len and isDigit(dialog[i]):
    num.add dialog[i]
    inc i

  debug "parseState num:" & num
  
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

proc toSquirrel(json: JsonNode): HSQObject =
  sq_resetobject(result)
  case json.kind:
  of JString:
    push(gVm.v, json.getStr())
    discard get(gVm.v, -1, result)
  of JInt:
    push(gVm.v, json.getInt())
    discard get(gVm.v, -1, result)
  of JBool:
    push(gVm.v, json.getBool())
    discard get(gVm.v, -1, result)
  of JFloat:
    push(gVm.v, json.getFloat())
    discard get(gVm.v, -1, result)
  of JNull:
    discard
  of JArray:
    sq_newarray(gVm.v, 0)
    for j in json.getElems():
      push(gVm.v, toSquirrel(j))
      discard sq_arrayappend(gVm.v, -2)
    discard get(gVm.v, -1, result)
    sq_addref(gVm.v, result)
  of JObject:
    sq_newtable(gVm.v)
    for (k,v) in json.getFields().pairs:
      push(gVm.v, k)
      push(gVm.v, toSquirrel(v))
      discard sq_newslot(gVm.v, -3, SQFalse)
    discard get(gVm.v, -1, result)
    sq_addref(gVm.v, result)

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
        let arg = toSquirrel(callBackHash["param"])
        gEngine.callbacks.add newCallback(id, time, name, @[arg])
      else:
        gEngine.callbacks.add newCallback(id, time, name, @[])
  setCallbackId(json["nextGuid"].getInt())

proc loadGlobals(json: JsonNode) =
  info "loadGlobals"
  var g: HSQOBJECT
  getf(rootTbl(gVm.v), "g", g)
  assert g.objType == OT_TABLE
  for (k, v) in json.pairs:
    debug "load globals " & k
    setf(g, k, toSquirrel(v))

proc room(name: string): Room =
  for room in gEngine.rooms:
    if room.name == name:
      return room

proc setRoom(name: string) =
  gEngine.setRoom(room(name))

proc setActor(key: string) =
  for actor in gEngine.actors:
    if actor.key == key:
      gEngine.setCurrentActor(actor, false)
      return

proc loadActor(actor: Object, json: JsonNode) =
  for (k,v) in json.pairs:
    case k:
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
    of "_dir":
      actor.setFacing(v.getInt().Facing)
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
    of "_volume":
      actor.volume = v.getFloat()
    elif not k.startsWith('_'):
      actor.table.setf(k, toSquirrel(v))
    else:
      warn fmt"load actor: key '{k}' is unknown"
  
  if actor.table.rawexists("postLoad"):
    sqCall(actor.table, "postLoad", [])

proc invObj(key: string): Object =
  for obj in gEngine.inventory:
    if obj.key == key:
      return obj

proc obj(key: string): Object =
  for o in gEngine.inventory:
    if o.key == key:
      return o
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

proc loadInventory(json: JsonNode) =
  if json.kind != JNull:
    let jSlots = json["slots"]
    for i in 0..<gEngine.hud.actorSlots.len:
      let actor = gEngine.hud.actorSlots[i].actor
      actor.inventory.setLen 0
      let jSlot = jSlots[i]
      if jSlot.hasKey "objects":
        if jSlot["objects"].kind != JNull:
          for jObj in jSlot["objects"]:
            let obj = invObj(jObj.getStr())
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
  for (k,v) in json.pairs:
    case k:
    of "_pos":
      obj.node.pos = vec2f(parseVec2i(v.getStr()))
    of "_state":
      obj.setState(v.getInt(), true)
    of "_rotation":
      obj.node.rotation = v.getFloat()
    of "_touchable":
      obj.touchable = v.getInt() != 0
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
      if obj.table.rawexists(k):
        obj.table.setf(k, toSquirrel(v))
      else:
        obj.table.newf(k, toSquirrel(v))
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
  for (k,v) in json.pairs:
    case k:
    of "_pseudoObjects":
      loadPseudoObjects(room, v)
    else:
      if not k.startsWith('_'):
        room.table.setf(k, toSquirrel(v))
      else:
        warn fmt"load room: key '{k}' is unknown"
  
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
  loadGameScene(json["gameScene"])
  loadDialog(json["dialog"])
  loadCallbacks(json["callbacks"])
  loadGlobals(json["globals"])
  loadActors(json["actors"])
  loadInventory(json["inventory"])
  loadRooms(json["rooms"])
  gEngine.time = json["gameTime"].getFloat
  gEngine.inputState.setState(json["inputState"].getInt().InputStateFlag)
  loadObjects(json["objects"])
  setActor(json["selectedActor"].getStr())
  setRoom(json["currentRoom"].getStr())

  setf(rootTbl(gVm.v), "SAVEBUILD", json["savebuild"].getInt())

  sqCall("postLoad", [])

type
  EngineGameLoader = ref object of GameLoader

method load(self: EngineGameLoader, json: JsonNode) =
  loadGame(json)

proc newEngineGameLoader*(): GameLoader =
  EngineGameLoader()

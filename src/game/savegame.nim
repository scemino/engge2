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
import ../game/engine
import ../game/ids
import ../game/gameloader

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
        arg = toSquirrel(callBackHash["param"])
      gEngine.callbacks.add newCallback(id, time, name, @[arg])
  setCallbackId(json["nextGuid"].getInt())

proc loadGlobals(json: JsonNode) =
  info "loadGlobals"
  var g: HSQOBJECT
  getf(rootTbl(gVm.v), "g", g)
  assert g.objType == OT_TABLE
  for (k, v) in json.pairs:
    debug "load globals " & k
    setf(g, k, toSquirrel(v))

proc setRoom(name: string) =
  for room in gEngine.rooms:
    if room.name == name:
      gEngine.setRoom(room)
      return

proc setActor(key: string) =
  for actor in gEngine.actors:
    if actor.key == key:
      gEngine.setCurrentActor(actor, false)
      return

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
  # loadActors(json["actors"])
  # loadInventory(json["inventory"])
  # loadRooms(json["rooms"])
  gEngine.time = json["gameTime"].getFloat
  # setInputState(json["inputState"].getInt())
  # loadObjects(json["objects"])
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

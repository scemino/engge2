import std/strformat
import glm
import sqnim
import ../debugtool
import ../../game/camera
import ../../game/engine
import ../../game/prefs
import ../../game/room
import ../../game/walkbox
import ../../game/shaders
import ../../scenegraph/dialog
import ../../scenegraph/walkboxnode
import ../../scenegraph/node
import ../../scenegraph/pathnode
import nglib
import ../../sys/app
import ../../script/vm

const
  RoomEffects = "None\0Sepia\0EGA\0VHS\0Ghost\0Black & White\0\0"
  FadeEffects = "None\0In\0Out\0Wobble\0\0"
  WalkboxModes = "None\0Merged\0All\0\0"

type
  GeneralTool = ref object of DebugTool
    fadeEffect: int32
    fadeDuration: float32
    fadeToSepia: bool
    walkboxMode: int32
  WinStatus* = object
    name: string
    visible: ptr bool

var
  gPathNode: PathNode
  gWalkboxNode: WalkboxNode
  gWinVisibles: seq[WinStatus]

proc newGeneralTool*(): GeneralTool =
  result = GeneralTool(fadeDuration: 3f)

proc addTool*(name: string, visible: ptr bool) =
  gWinVisibles.add  WinStatus(name: name, visible: visible)

proc getRoom(data: pointer, idx: int32, outText: ptr cstringConst): bool {.cdecl.} =
  if idx in 0..<gEngine.rooms.len:
    outText[] = cast[cstringConst](gEngine.rooms[idx].name[0].addr)
    result = true
  else:
    result = false

proc getSelActors(): seq[Object] =
  for slot in gEngine.hud.actorSlots:
    if slot.selectable:
      result.add slot.actor

proc getActor(data: pointer, idx: int32, outText: ptr cstringConst): bool {.cdecl.} =
  let actors = getSelActors()
  if idx in 0..<actors.len:
    outText[] = cast[cstringConst](actors[idx].key[0].unsafeAddr)
    result = true
  else:
    result = false

proc text(state: DialogState): string =
  case state:
  of DialogState.None: result = "no"
  of DialogState.Active: result = "active"
  of DialogState.WaitingForChoice: result = "waiting for choice"

proc speedFactor(label: string, speeds: openArray[float32], value: ptr float32) =
  igText(label.cstring)
  for speed in speeds:
    igSameLine()
    if igButton((fmt"{speed:.1f}").cstring):
      value[] = speed

method render*(self: GeneralTool) =
  if gEngine.isNil or not gGeneralVisible:
    return

  igSetNextWindowSize(ImVec2(x: 520, y: 600), ImGuiCond.FirstUseEver)
  igBegin("General".cstring, addr gGeneralVisible)

  let inCutscene = not gEngine.cutscene.isNil
  let scrPos = winToScreen(mousePos())
  let roomPos = if gEngine.room.isNil: vec2f(0f, 0f) else: gEngine.room.screenToRoom(scrPos)
  igText("In cutscene: %s", if inCutscene: "yes".cstring else: "no".cstring)
  igText("Dialog: %s", text(gEngine.dlg.state).cstring)
  igText("Verb: %d", gEngine.hud.verb.id)
  igText("Pos (screen): (%.0f, %0.f)", scrPos.x, scrPos.y)
  igText("Pos (room): (%.0f, %0.f)", roomPos.x, roomPos.y)
  igText("VM stack top: %d", sq_gettop(gVm.v))
  speedFactor("Game speed factor", [0.5f, 1f, 5f, 10f], tmpPrefs().gameSpeedFactor.addr)
  igCheckbox("HUD", gEngine.inputState.inputHUD.addr)
  igCheckbox("Input", gEngine.inputState.inputActive.addr)
  igCheckbox("Cursor", gEngine.inputState.showCursor.addr)
  igCheckbox("Verbs", gEngine.inputState.inputVerbsActive.addr)

  let actors = getSelActors()
  var actorIndex = actors.find(gEngine.actor).int32
  if igCombo("Actor", actorIndex.addr, getActor, nil, actors.len.int32, -1'i32):
    gEngine.setCurrentActor(actors[actorIndex])

  let room = gEngine.room
  var index = gEngine.rooms.find(room).int32
  if igCombo("Room", index.addr, getRoom, nil, gEngine.rooms.len.int32, -1'i32):
    gEngine.setRoom(gEngine.rooms[index])

  # windows
  if igCollapsingHeader("Windows"):
    for status in gWinVisibles:
      igCheckbox(status.name.cstring, status.visible)

  # camera
  if igCollapsingHeader("Camera"):
    igText("Camera follow: %s", if gEngine.followActor.isNil: "(none)".cstring else: gEngine.followActor.key.cstring)
    igText("Camera isMoving: %s", if gEngine.camera.isMoving: "yes".cstring else: "no")
    let halfScreenSize = vec2f(gEngine.room.getScreenSize()) / 2.0f
    var camPos = gEngine.cameraPos() - halfScreenSize
    if igDragFloat2("Camera pos", camPos.arr):
      gEngine.follow(nil)
      gEngine.cameraAt(camPos)
    igDragFloat4("Bounds", gEngine.camera.bounds.arr)

  if not room.isNil:
    if igCollapsingHeader("Room"):
      igText("Sheet: %s", room.sheet[0].addr)
      igText("Size: %d x %d", room.roomSize.x, room.roomSize.y)
      igText("Fullscreen: %d", room.fullScreen)
      igText("Height: %d", room.height)
      var overlay = room.overlay
      if igColorEdit4("Overlay", overlay.arr):
        room.overlay = overlay
      if igCollapsingHeader("Walkboxes"):
        if igButton("Reset") and not room.pathFinder.isNil:
          room.pathFinder.graph = nil
        if igCombo("Walkbox", self.walkboxMode.addr, WalkboxModes):
          if self.walkboxMode != WalkboxMode.None.int32:
            if gPathNode.isNil:
              gPathNode = newPathNode()
              gEngine.screen.addChild gPathNode
            if gWalkboxNode.isNil:
              gWalkboxNode = newWalkboxNode()
              gEngine.scene.addChild gWalkboxNode
            gWalkboxNode.mode = self.walkboxMode.WalkboxMode
          else:
            gPathNode.remove()
            gWalkboxNode.remove()
            gPathNode = nil
            gWalkboxNode = nil
        igSeparator()

        var wbName: string
        if self.walkboxMode == WalkboxMode.All.int32:
          var i = 0
          for wb in room.walkboxes.mitems:
            let name = if wb.name.len > 0: wb.name else: fmt"walkbox #{i}"
            if wb.contains(gEngine.actor.node.pos):
              wbName = name
            igCheckbox(name.cstring, wb.visible.addr)
            inc i
        elif self.walkboxMode == WalkboxMode.Merged.int32:
          var i = 0
          for wb in room.mergedPolygon.mitems:
            let name = if wb.name.len > 0: wb.name else: fmt"walkbox #{i}"
            if wb.contains(gEngine.actor.node.pos):
              wbName = name
            igCheckbox(name.cstring, wb.visible.addr)
            inc i
        igText(fmt"actor in {wbName}".cstring)

      if not gEngine.room.isNil and not gEngine.room.pathFinder.isNil and not gEngine.room.pathFinder.graph.isNil:
        let graph = gEngine.room.pathFinder.graph
        if igCollapsingHeader("Graph"):
          if igTreeNode(fmt"nodes ({graph.nodes.len})##graph".cstring):
            for node in graph.nodes:
              igText(fmt"x={node.x}, y={node.y}".cstring)
            igTreePop()
          var edgeCount = 0
          for i in 0..<graph.edges.len:
            edgeCount = edgeCount + graph.edges[i].len
          if igTreeNode(fmt"edges ({edgeCount})##graph".cstring):
            for i in 0..<graph.edges.len:
              let edge = graph.edges[i]
              if edge.len > 0 and igTreeNode(fmt"edge{i+1}".cstring):
                for e in edge:
                  igText(fmt"edge (s={e.start}, t={e.to}) = {e.cost}".cstring)
                igTreePop()
            igTreePop()
          if igTreeNode(fmt"concaveVertices ({graph.concaveVertices.len})##graph".cstring):
            for i in 0..<graph.concaveVertices.len:
              let vtx = graph.concaveVertices[i]
              igText(fmt"x={vtx.x}, y={vtx.y}".cstring)
            igTreePop()

      if igCollapsingHeader("Room Shader"):
        var effect = room.effect.int32
        if igCombo("effect", effect.addr, RoomEffects):
          room.effect = effect.RoomEffect
        igDragFloat("iFade", gShaderParams.iFade.addr, 0.01f, 0f, 1f);
        igDragFloat("wobbleIntensity", gShaderParams.wobbleIntensity.addr, 0.01f, 0f, 1f)
        igDragFloat3("shadows", gShaderParams.shadows.arr, 0.01f, -1f, 1f)
        igDragFloat3("midtones", gShaderParams.midtones.arr, 0.01f, -1f, 1f)
        igDragFloat3("highlights", gShaderParams.highlights.arr, 0.01f, -1f, 1f)

      if igCollapsingHeader("Fade Shader"):
        igSeparator()
        igCombo("Fade effect", self.fadeEffect.addr, FadeEffects.cstring)
        igDragFloat("Duration", self.fadeDuration.addr, 0.1f, 0f, 10f)
        igCheckbox("Fade to sepia", self.fadeToSepia.addr)
        igText("Elapsed %f", gEngine.fadeEffect.elapsed)
        igText("Fade %f", gEngine.fadeEffect.fade)
        if igButton("GO"):
          gEngine.fadeTo(self.fadeEffect.FadeEffect, self.fadeDuration, self.fadeToSepia)

      igSeparator()

      if igCollapsingHeader("Layers"):
        for layer in room.layers:
          if layer.objects.len == 0:
            igText(fmt"Layer {$layer.zsort}".cstring)
          elif igTreeNode(fmt"Layer {$layer.zsort}".cstring):
            for obj in layer.objects:
              igText(fmt"{obj.name} ({obj.key})".cstring)
            igTreePop()

  igEnd()

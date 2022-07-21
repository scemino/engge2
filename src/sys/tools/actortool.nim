import std/strformat
import std/logging
import glm
import ../debugtool
import ../../game/engine
import ../../game/room
import ../../game/actor
import ../../libs/imgui
import ../../script/squtils
import ../../io/textdb
import ../../scenegraph/node

type ActorTool = ref object of DebugTool

proc newActorTool*(): ActorTool =
  result = ActorTool()

var 
  gActorsVisible = true
  gActor: Object
  gShowProperties = true

proc showNode(obj: Object, node: Node) =
  var v = node.visible
  if igCheckbox(fmt"##{node.name}".cstring, v.addr):
    obj.showLayer(node.name, not node.visible)
  igSameLine()
  if node.children.len > 0:
    igSameLine()
    if igTreeNode(node.name.cstring):
      for subNode in node.children:
        obj.showNode(subNode)
      igTreePop()
  else:
    igText(node.name.cstring)

proc showProperties() =
  if not gActor.isNil and gShowProperties:
    let actorRoom = if gActor.room.isNil: "Void" else: gActor.room.name
    igBegin("Actor properties", addr gShowProperties)
    igCheckbox("Use Walkboxes", addr gActor.useWalkboxes)
    igText("Room: %s", actorRoom.cstring)
    igText("Facing: %s", ($gActor.facing).cstring)
    igText("Z-Order: %d", gActor.node.getZSort())
    if gActor.room.isNil:
      igText("Scale: N/A")
    else:
      igText("Scale: %.3f", gActor.node.getScale().x)
    var color = gActor.node.realColor
    if igColorEdit4("Color", color.arr):
      gActor.node.color = color
    igColorEdit4("Talk color", gActor.talkColor.arr)
    igDragInt2("Talk offset", gActor.talkOffset.arr)
    igDragFloat2("Position", gActor.node.pos.arr)
    igDragFloat2("Offset", gActor.node.offset.arr)
    igDragFloat("Volume", addr gActor.volume, 1f, 0f, 1f)
    igDragFloat2("WalkSpeed", gActor.walkSpeed.arr)
    igSeparator()
    gActor.showNode(gActor.node)
    igEnd()

method render*(self: ActorTool) =
  if gEngine.isNil or not gActorsVisible:
    return

  igBegin("Actors".cstring, addr gActorsVisible)

  # show actor list
  for actor in gEngine.actors:
    let selected = gActor == actor
    igPushID(actor.table.getId().int32)
    igCheckbox("", addr actor.node.visible)
    igSameLine()
    if igSelectable(getText(actor.name()).cstring, selected):
      gActor = actor
    igPopID()

  showProperties()

  igEnd()

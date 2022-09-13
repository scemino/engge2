import std/strformat
import std/tables
import glm
import ../debugtool
import ../../game/engine
import ../../game/room
import ../../game/actor
import ../../game/motors/motor
import ../../libs/imgui
import ../../script/squtils
import ../../io/textdb
import ../../scenegraph/node

type ActorTool = ref object of DebugTool
  visible*: bool

proc newActorTool*(): ActorTool =
  result = ActorTool()

var 
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
    igText("Walking: %s", if not gActor.walkTo.isNil and gActor.walkTo.enabled: "yes".cstring else: "no".cstring)
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
    igDragFloat2("Use Position", gActor.usepos.arr)
    igDragFloat2("Offset", gActor.node.offset.arr)
    igDragFloat2("Render Offset", gActor.node.renderOffset.arr)
    igDragFloat("Volume", addr gActor.volume, 1f, 0f, 1f)
    igDragInt4("Hotspot", gActor.hotspot.arr)
    igDragFloat2("WalkSpeed", gActor.walkSpeed.arr)
    igSeparator()
    if igCollapsingHeader("Animation names"):
      igText("Head: %s", gActor.getAnimName(HeadAnimName).cstring)
      igText("Stand: %s", gActor.getAnimName(StandAnimName).cstring)
      igText("Walk: %s", gActor.getAnimName(WalkAnimName).cstring)
      igText("Reach: %s", gActor.getAnimName(ReachAnimName).cstring)
    if igCollapsingHeader("Hidden layers"):
      for layer in gActor.hiddenLayers:
        igText(layer.cstring)
    if igCollapsingHeader("Node"):
      gActor.showNode(gActor.node)
    igEnd()

method render*(self: ActorTool) =
  if gEngine.isNil or not self.visible:
    return

  igSetNextWindowSize(ImVec2(x: 520, y: 600), ImGuiCond.FirstUseEver)
  igBegin("Actors".cstring, addr self.visible)

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

import glm
import std/strformat
import std/tables
import ../debugtool
import ../../game/engine
import ../../game/room
import ../../gfx/texture
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

proc showProperties() =
  if not gActor.isNil and gShowProperties:
    igBegin("Actor properties", addr gShowProperties)
    igCheckbox("Use Walkboxes", addr gActor.useWalkboxes)
    igText("Room: %s", gActor.room.name)
    igText("Facing: %s", $gActor.facing)
    igText("Z-Order: %d", gActor.node.getZSort())
    igText("Scale: %.3f", gActor.node.getScale().x)
    igColorEdit4("Color", gActor.node.nodeColor.arr)
    igColorEdit4("Talk color", gActor.talkColor.arr)
    igDragInt2("Talk offset", gActor.talkOffset.arr)
    igDragFloat2("Position", gActor.node.pos.arr)
    igDragFloat2("Offset", gActor.node.offset.arr)
    igDragFloat("Volume", addr gActor.volume, 1f, 0f, 1f)
    igDragFloat2("WalkSpeed", gActor.walkSpeed.arr)
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

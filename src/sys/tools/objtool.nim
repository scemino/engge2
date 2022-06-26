import glm
import sqnim
import ../debugtool
import ../../game/engine
import ../../game/room
import ../../libs/imgui
import ../../script/squtils
import ../../io/textdb
import ../../scenegraph/node

type ObjectTool = ref object of DebugTool

proc newObjectTool*(): ObjectTool =
  result = ObjectTool()

var 
  gObjectsVisible = true
  gObject: Object
  gShowProperties = true

proc showProperties() =
  if not gObject.isNil and gShowProperties:
    let objRoom = if gObject.room.isNil: "Void" else: gObject.room.name
    igBegin("Object properties", addr gShowProperties)
    igText("Key: %s", gObject.key.cstring)
    igText("Name: %s", getText(gObject.name()).cstring)
    igCheckbox("Touchable", gObject.touchable.addr)
    igText("Room: %s", objRoom.cstring)
    igText("Facing: %d", gObject.facing)
    igDragInt("Z-Order: ", gObject.node.zOrder.addr)
    if gObject.room.isNil:
      igText("Scale: N/A")
    else:
      igText("Scale: %.3f", gObject.node.getScale().x)
    igColorEdit4("Color", gObject.node.nodeColor.arr)
    igDragFloat2("Position", gObject.node.pos.arr)
    igDragFloat2("Offset", gObject.node.offset.arr)
    igDragFloat("Volume", addr gObject.volume, 1f, 0f, 1f)
    igEnd()

method render*(self: ObjectTool) =
  if gEngine.isNil or not gObjectsVisible:
    return

  igBegin("Objects".cstring, addr gObjectsVisible)

  # show object list
  for layer in gEngine.room.layers:
    for obj in layer.objects.mitems:
      let selected = gObject == obj
      igPushID(obj.table.getId().int32)
      igCheckbox("", addr obj.node.visible)
      igSameLine()
      if igSelectable(obj.key.cstring, selected):
        gObject = obj
      igPopID()

  showProperties()

  igEnd()

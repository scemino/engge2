import std/strformat
import sqnim
import ../debugtool
import ../../game/engine
import ../../game/room
import ../../libs/imgui
import ../../script/squtils
import ../../io/textdb
import ../../scenegraph/node

type ObjectTool = ref object of DebugTool
  gFilterObject: ImGuiTextFilter

proc newObjectTool*(): ObjectTool =
  result = ObjectTool()

var 
  gObjectsVisible = true
  gObject: Object
  gShowProperties = true

proc animIndex(): int32 =
  for i in 0..<gObject.anims.len:
    let anim = gObject.anims[i]
    if anim.name == gObject.animName:
      return i.int32
  -1'i32

proc getAnim(data: pointer, idx: int32, out_text: ptr constChar): bool {.cdecl.} =
  if idx in 0..<gObject.anims.len:
    out_text[] = cast[constChar](gObject.anims[idx].name[0].addr)
    result = true
  else:
    result = false

proc showProperties() =
  if not gObject.isNil and gShowProperties:
    let objRoom = if gObject.room.isNil: "Void" else: gObject.room.name
    var animIdx = animIndex()

    igBegin("Object properties", addr gShowProperties)
    igText("Key: %s", gObject.key.cstring)
    igText("Name: %s", getText(gObject.name()).cstring)
    igSeparator()
    igText("State: %d", gObject.state)
    if igCombo("Anim", animIdx.addr, getAnim, nil, gObject.anims.len.int32, -1'i32):
      gObject.play(gObject.anims[animIdx].name)
    igSeparator()
    igCheckbox("Touchable", gObject.touchable.addr)
    igColorEdit4("Color", gObject.node.nodeColor.arr)
    igText("Room: %s", objRoom.cstring)
    igText("Facing: %d", gObject.facing)
    igDragInt("Z-Order", gObject.node.zOrder.addr)
    igDragFloat("Volume", addr gObject.volume, 1f, 0f, 1f)
    igSeparator()
    igDragFloat2("Position", gObject.node.pos.arr)
    igDragFloat("Rotation", gObject.node.rotation.addr)
    igDragFloat2("Scale", gObject.node.scale.arr)
    igDragFloat2("Offset", gObject.node.offset.arr)
    igEnd()

method render*(self: ObjectTool) =
  if gEngine.isNil or not gObjectsVisible:
    return

  igBegin("Objects".cstring, addr gObjectsVisible)
  self.gFilterObject.addr.draw()

  # show object list
  for layer in gEngine.room.layers:
    for obj in layer.objects.mitems:
      if self.gFilterObject.addr.passFilter(obj.key.cstring):
        let selected = gObject == obj
        igPushID(obj.table.getId().int32)
        igCheckbox("", addr obj.node.visible)
        igSameLine()
        let name = if obj.key == "": obj.name else: fmt"{obj.name}({obj.key})"
        if igSelectable(name.cstring, selected):
          gObject = obj
        igPopID()

  showProperties()

  igEnd()

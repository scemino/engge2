import std/strformat
import glm
import sqnim
import ../debugtool
import ../../game/engine
import ../../game/room
import nglib
import ../../script/squtils
import ../../io/textdb
import ../../scenegraph/node
import ../../scenegraph/debugobj

type ObjectTool = ref object of DebugTool
  objFilter: ImGuiTextFilter
  visible*: bool

proc newObjectTool*(): ObjectTool =
  result = ObjectTool()

var 
  gObject: Object
  gShowProperties = true
  gObjNode: DebugObject

proc animIndex(): int32 =
  for i in 0..<gObject.anims.len:
    let anim = gObject.anims[i]
    if anim.name == gObject.animName:
      return i.int32
  -1'i32

proc getAnim(data: pointer, idx: int32, out_text: ptr cstringConst): bool {.cdecl.} =
  if idx in 0..<gObject.anims.len:
    out_text[] = cast[cstringConst](gObject.anims[idx].name[0].addr)
    result = true
  else:
    result = false

proc showProperties() =
  if not gObject.isNil and gShowProperties:
    if gObjNode.isNil or gObject != gObjNode.obj:
      if not gObjNode.isNil:
        gObjNode.remove()
      gObjNode = newDebugObject(gObject)
      gEngine.screen.addChild gObjNode

    let objRoom = if gObject.room.isNil: "Void" else: gObject.room.name
    var animIdx = animIndex()

    igBegin("Object properties", addr gShowProperties)
    igText("Key: %s", gObject.key.cstring)
    igText("Name: %s", getText(gObject.name()).cstring)
    igText("Type: %s", ($gObject.objType).cstring)
    if gObject.objType == otTrigger:
      let state = if gObject.triggerActive: "yes" else: "no"
      igText("Trigger active: %s", state.cstring)
    igSeparator()
    var state = gObject.state.int32
    if igInputInt("State", state.addr):
      gObject.setState(state.int)
    if igCombo("Anim", animIdx.addr, getAnim, nil, gObject.anims.len.int32, -1'i32):
      gObject.play(gObject.anims[animIdx].name)
    igSeparator()
    var touchable = gObject.touchable
    if igCheckbox("Touchable", touchable.addr):
      gObject.touchable = touchable
    var color = gObject.node.realColor
    if igColorEdit4("Color", color.arr):
      gObject.node.color = color
      gObject.node.alpha = color[3]
    igText("Room: %s", objRoom.cstring)
    if gObject.layer.isNil:
      igText("Layer: (none)")
    else:
      igText("Layer: %d", gObject.layer.zsort)
    igText("Facing: %d", gObject.facing)
    igDragInt("Z-Order", gObject.node.zOrder.addr)
    igDragFloat("Volume", addr gObject.volume, 1f, 0f, 1f)
    igDragInt4("Hotspot", gObject.hotspot.arr)
    igDragFloat2("Use Position", gObject.usepos.arr)
    igSeparator()
    igDragFloat2("Position", gObject.node.pos.arr)
    igDragFloat("Rotation", gObject.node.rotation.addr)
    igDragFloat2("Scale", gObject.node.scale.arr)
    igDragFloat2("Offset", gObject.node.offset.arr)
    igEnd()

method render*(self: ObjectTool) =
  if gEngine.isNil or not self.visible:
    return

  igSetNextWindowSize(ImVec2(x: 520, y: 600), ImGuiCond.FirstUseEver)
  igBegin("Objects".cstring, addr self.visible)
  self.objFilter.addr.draw()

  # show object list
  for layer in gEngine.room.layers:
    for obj in layer.objects.mitems:
      if self.objFilter.addr.passFilter(obj.key.cstring):
        let selected = gObject == obj
        igPushID(obj.table.getId().int32)
        igCheckbox("", addr obj.node.visible)
        igSameLine()
        let name = if obj.key == "": obj.name else: fmt"{obj.name}({obj.key}) {obj.table.getId()}"
        if igSelectable(name.cstring, selected):
          gObject = obj
        igPopID()

  showProperties()

  igEnd()

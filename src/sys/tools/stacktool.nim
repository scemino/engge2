import std/strformat
import sqnim
import ../debugtool
import ../../game/ids
import ../../libs/imgui
import ../../script/vm
import ../../script/squtils
import ../../util/utils

type 
  StackTool = ref object of DebugTool

proc newStackTool*(): StackTool =
  result = StackTool()

proc tableType(obj: var HSQOBJECT): string =
  let id = obj.getId()
  if isRoom(id):
    result = fmt"room (id: {id})"
  elif isActor(id):
    result = fmt"actor (id: {id})"
  elif isObject(id):
    result = fmt"object (id: {id})"
  elif isSound(id):
    result = fmt"sound (id: {id})"
  elif isLight(id):
    result = fmt"light (id: {id})"
  elif isCallback(id):
    result = fmt"callback (id: {id})"
  else:
    result = fmt"table (id: {id})"

proc typeToStr(obj: var HSQOBJECT): string =
  case obj.objType:
  of OT_INTEGER:
    result = fmt"{sq_objtointeger(obj)} (int)"
  of OT_TABLE:
    result = tableType(obj)
  of OT_ARRAY:
    result = "array"
  of OT_BOOL:
    result = fmt"{sq_objtointeger(obj)} (bool)"
  of OT_CLOSURE:
    result = "closure"
  of OT_FLOAT:
    result = fmt"{sq_objtofloat(obj)} (float)"
  of OT_NATIVECLOSURE:
    result = "native closure"
  of OT_STRING:
    result = fmt"{sq_objtostring(obj)} (string)"
  of OT_THREAD:
    let v = cast[HSQUIRRELVM](obj.value.pThread)
    let t = thread(v)
    if not t.isNil:
      result = fmt"thread '{t.name}'"
    else:
      result = "thread"
  else:
    result = fmt"{obj.objType:X}"

method render*(self: StackTool) =
  igSetNextWindowSize(ImVec2(x: 520, y: 600), ImGuiCond.FirstUseEver)
  igBegin("Stack")
  igBeginChild("ScrollingRegion")
  let size = sq_gettop(gVm.v)
  igText(fmt"size: {size}".cstring)
  var obj: HSQOBJECT
  for i in 1..size:
    discard sq_getstackobj(gVm.v, -i, obj)
    igText(fmt"obj type: {typeToStr(obj)}".cstring)
  igEndChild()
  igEnd()
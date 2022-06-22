import std/[logging, strformat, os]
import sqnim
import nimyggpack
import glm
import ../io/ggpackmanager
import ../gfx/recti

proc onError(v: HSQUIRRELVM, desc: SQString, source: SQString, line: SQInteger, column: SQInteger) {.cdecl.} =
  echo fmt"{source}({line},{column}): {desc}"

type VM* = ref object of RootObj
  v*: HSQUIRRELVM

var gVm*: VM

proc newVM*(): VM =
  new(result)
  result.v = sq_open(1024)
  sq_setprintfunc(result.v, printfunc, printfunc)
  sqstd_seterrorhandlers(result.v)
  sq_setcompilererrorhandler(result.v, onError)
  gVm = result

proc destroy*(self: VM) =
  sq_close(self.v)
  
proc push*(v: HSQUIRRELVM, value: bool) {.inline.} =
  sq_pushbool(v, if value: SQTrue else: SQFalse)

proc push*(v: HSQUIRRELVM, value: int64) {.inline.} =
  sq_pushinteger(v, value.SQInteger)

proc push*(v: HSQUIRRELVM, value: int) {.inline.} =
  sq_pushinteger(v, value.SQInteger)

proc push*(v: HSQUIRRELVM, value: string) {.inline.} =
  sq_pushstring(v, value, -1)

proc push*(v: HSQUIRRELVM, value: float) {.inline.} =
  sq_pushfloat(v, value)

proc push*(v: HSQUIRRELVM, value: HSQOBJECT) {.inline.} =
  sq_pushobject(v, value)

proc push*(v: HSQUIRRELVM, pos: Vec2i) {.inline.} =
  sq_newtable(gVm.v)
  sq_pushstring(v, "x", -1)
  sq_pushinteger(v, pos.x)
  discard sq_newslot(v, -3, SQFalse)
  sq_pushstring(v, "y", -1)
  sq_pushinteger(v, pos.y)
  discard sq_newslot(v, -3, SQFalse)

proc push*(v: HSQUIRRELVM, pos: Vec2f) {.inline.} =
  push(v, vec2(pos.x.int32,pos.y.int32))

proc push*(v: HSQUIRRELVM, rect: Recti) {.inline.} =
  sq_newtable(v)
  sq_pushstring(v, "x1", -1)
  sq_pushinteger(v, rect.left)
  discard sq_newslot(v, -3, SQFalse)
  sq_pushstring(v, "y1", -1)
  sq_pushinteger(v, rect.top)
  discard sq_newslot(v, -3, SQFalse)
  sq_pushstring(v, "x2", -1)
  sq_pushinteger(v, rect.right)
  discard sq_newslot(v, -3, SQFalse)
  sq_pushstring(v, "y2", -1)
  sq_pushinteger(v, rect.bottom)
  discard sq_newslot(v, -3, SQFalse)

proc setdelegate*(obj, del: HSQOBJECT) =
  push(gVm.v, obj)
  push(gVm.v, del)
  discard sq_setdelegate(gVm.v, -2)
  sq_pop(gVm.v, 1)

proc set*[T](v: HSQUIRRELVM, obj: HSQOBJECT, name: string, value: T) =
  sq_pushobject(v, obj)
  sq_pushstring(v, name, -1)
  push(v, value)
  discard sq_newslot(v, -3, SQFalse)
  sq_pop(v, 1)

proc regConst*[T](v: HSQUIRRELVM, name: string, value: T) =
  sq_pushconsttable(v)
  v.push(name)
  v.push(value)
  discard sq_newslot(v, -3, SQTrue)
  sq_pop(v, 1)

proc regConsts*[T](v: HSQUIRRELVM, consts: seq[tuple[k: string, v: T]]) =
  for (k, val) in consts:
    v.regConst(k, val)

proc execNut*(v: HSQUIRRELVM, name, code: string) =
  info fmt"exec file {name}"
  let top = sq_gettop(v)
  if SQ_FAILED(sq_compilebuffer(v, code, code.len, name, SQTrue)):
    error "Error compiling " & name
    sqstd_printcallstack(v)
    return
  sq_pushroottable(v)
  if SQ_FAILED(sq_call(v, 1, SQFalse, SQTrue)):
    error "Error calling " & name
    sqstd_printcallstack(v)
    sq_pop(v, 1) # removes the closure
    return
  sq_settop(v, top)
  
proc execNutFile*(v: HSQUIRRELVM, path: string) =
  let code = readFile(path)
  execNut(v, path, code)

proc execBnutEntry*(v: HSQUIRRELVM, entry: string) =
  let code = bnutDecode(gGGPackMgr.loadString(entry))
  execNut(v, entry, code)

proc replaceExt(entry: string, ext: string): string =
  var (dir, name, _) = splitFile(entry)
  dir & name & ext

proc execNutEntry*(v: HSQUIRRELVM, entry: string) =
  if gGGPackMgr.assetExists(entry):
    info fmt"read existing '{entry}'"
    let code = gGGPackMgr.loadString(entry)
    execNut(v, entry, code)
  else:
    var newEntry = replaceExt(entry, ".bnut")
    info fmt"read existing '{newEntry}'"
    if gGGPackMgr.assetExists(newEntry):
      execBnutEntry(v, newEntry)
    else:
      error fmt"'{entry}' and '{newEntry}' have not been found"


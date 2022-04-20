import std/[logging, strformat]
import sqnim
import glm
import ../gfx/recti

proc onError(v: HSQUIRRELVM, desc: SQString, source: SQString, line: SQInteger, column: SQInteger) {.cdecl.} =
  echo fmt"{source}({line},{column}): {desc}"

type VM* = ref object of RootObj
  v*: HSQUIRRELVM

var gVm*: VM

proc newVM*(): VM =
  new(result)
  result.v = sq_open(1024)
  sqstd_register_stringlib(result.v)
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

proc execNut*(self: VM, name, code: string) =
  sq_pushroottable(self.v)
  if SQ_FAILED(sq_compilebuffer(self.v, code, code.len, name, SQTrue)):
    error "Error compiling " & name
    sqstd_printcallstack(self.v)
    return
  var obj: HSQOBJECT
  discard sq_getstackobj(self.v, -1, obj)
  sq_addref(self.v, obj)
  sq_pop(self.v, 1)
  sq_pushobject(self.v, obj)
  sq_pushroottable(self.v)
  if SQ_FAILED(sq_call(self.v, 1, SQFalse, SQTrue)):
    error "Error calling " & name
    sqstd_printcallstack(self.v)
    return
  sq_pop(self.v, 1)
  
proc execNutFile*(self: VM, path: string) =
  let code = readFile(path)
  self.execNut(path, code)

import std/sequtils
import sqnim
import ../game/engine
import ../game/room
import ../game/light
import ../game/thread
import ../script/squtils
import ../util/easing
import ../audio/audio

proc soundDef*(id: int): SoundDefinition =
  for sound in gEngine.audio.soundDefs:
    if sound.id == id:
      return sound

proc soundDef*(v: HSQUIRRELVM, i: int): SoundDefinition =
  var id: int
  if SQ_SUCCEEDED(get(v, i, id)):
    result = soundDef(id)

proc sound*(id: int): SoundId =
  for sound in gEngine.audio.sounds:
    if not sound.isNil and sound.id == id:
      return sound

proc sound*(v: HSQUIRRELVM, i: int): SoundId =
  var id: int
  if SQ_SUCCEEDED(get(v, i, id)):
    result = sound(id)

proc room*(id: int): Room =
  for room in gEngine.rooms:
    if room.table.getId() == id:
      return room

proc room*(table: HSQOBJECT): Room =
  for room in gEngine.rooms:
    if room.table == table:
      return room

proc room*(v: HSQUIRRELVM, i: int): Room =
  var table: HSQOBJECT
  if SQ_SUCCEEDED(get(v, i, table)):
    result = room(table)

proc actor*(table: HSQOBJECT): Object =
  for actor in gEngine.actors:
    if actor.table == table:
      return actor

proc actor*(id: int): Object =
  for actor in gEngine.actors:
    if actor.id == id:
      return actor

proc actor*(v: HSQUIRRELVM, i: int): Object =
  var table: HSQOBJECT
  if SQ_SUCCEEDED(get(v, i, table)):
    result = actor(table)

iterator objs*(): Object =
  for actor in gEngine.actors:
    yield actor
  for room in gEngine.rooms:
    for layer in room.layers:
      for o in layer.objects:
        yield o

proc obj*(table: HSQOBJECT): Object =
  for obj in objs():
    if obj.table == table:
      return obj

proc obj*(id: int): Object =
  for obj in objs():
    if obj.id == id:
      return obj

proc obj*(v: HSQUIRRELVM, i: int): Object =
  var table: HSQOBJECT
  discard sq_getstackobj(v, i, table)
  obj(table)

proc objRoom*(table: HSQOBJECT): Room =
  for room in gEngine.rooms:
    for layer in room.layers:
      for o in layer.objects:
        if o.table == table:
          return room

proc thread*(v: HSQUIRRELVM): ThreadBase =
  if not gEngine.cutscene.isNil:
    if gEngine.cutscene.getThread() == v:
      return gEngine.cutscene
  var threads = gEngine.threads.toSeq
  for t in threads:
    if t.getThread() == v:
      return t

proc thread*(id: int): ThreadBase =
  if not gEngine.cutscene.isNil:
    if gEngine.cutscene.getId() == id:
      return gEngine.cutscene
  let threads = gEngine.threads.toSeq
  for t in threads:
    if t.getId() == id:
      return t

proc thread*(v: HSQUIRRELVM, i: int): ThreadBase =
  var id: int
  if SQ_SUCCEEDED(get(v, i, id)):
    result = thread(id)

proc light*(id: int): Light =
  if not gEngine.room.isNil:
    for i in 0..<gEngine.room.numLights:
      if gEngine.room.lights[i].id == id:
        return gEngine.room.lights[i]

proc light*(v: HSQUIRRELVM, i: int): Light =
  var id: int
  if SQ_SUCCEEDED(get(v, i, id)):
    result = light(id)

proc easing*(easing: int): easing_func =
  case easing and 7:
  of 0: linear
  of 1: easeIn
  of 2: easeInOut
  of 3: easeOut
  of 4: easeIn  # TODO: slowEaseIn
  of 5: easeOut # TODO: slowEaseOut
  else: linear

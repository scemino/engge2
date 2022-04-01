import sqnim
import squtils
import engine
import room
import actor
import ../util/easing

proc room*(id: int): Room =
  for room in gEngine.rooms:
    if room.table.getId() == id:
      return room
  nil

proc room*(table: HSQOBJECT): Room =
  for room in gEngine.rooms:
    if room.table == table:
      return room
  nil

proc room*(v: HSQUIRRELVM, i: int): Room =
  var table: HSQOBJECT
  if SQ_SUCCEEDED(get(v, i, table)):
    room(table)
  else:
    nil

proc actor*(table: HSQOBJECT): Actor =
  for actor in gEngine.actors:
    if actor.table == table:
      return actor
  nil

proc actor*(v: HSQUIRRELVM, i: int): Actor =
  var table: HSQOBJECT
  if SQ_SUCCEEDED(get(v, i, table)):
    actor(table)
  else:
    nil

proc obj*(table: HSQOBJECT): Object =
  for room in gEngine.rooms:
    for o in room.objects:
      if o.table == table:
        return o
  nil

proc obj*(v: HSQUIRRELVM, i: int): Object =
  var table: HSQOBJECT
  discard sq_getstackobj(v, i, table)
  obj(table)

proc objRoom*(table: HSQOBJECT): Room =
  for room in gEngine.rooms:
    for o in room.objects:
      if o.table == table:
        return room
  nil

proc easing*(easing: int): easing_func =
  case easing and 7:
  of 0: linear
  of 1: easeIn
  of 2: easeInOut
  of 3: easeOut
  of 4: easeIn  # TODO: slowEaseIn
  of 5: easeOut # TODO: slowEaseOut
  else: linear
import sqnim
import squtils
import engine
import room

proc room*(id: int): Room =
  for room in gEngine.rooms:
    if room.table.getId() == id:
      return room
  nil

proc obj*(table: HSQOBJECT): Object =
  for room in gEngine.rooms:
    for o in room.objects:
      if o.table == table:
        return o
  nil

proc objRoom*(table: HSQOBJECT): Room =
  for room in gEngine.rooms:
    for o in room.objects:
      if o.table == table:
        return room
  nil
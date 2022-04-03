const 
  START_ACTORID*    = 1000
  END_ACTORID*      = 2000
  START_ROOMID*     = 2000
  END_ROOMID*       = 3000
  START_OBJECTID*   = 3000
  END_OBJECTID*     = 100000
  START_LIGHTID*    = 100000
  END_LIGHTID*      = 200000
  START_SOUNDDEFID* = 200000
  END_SOUNDDEFID*   = 250000
  START_SOUNDID*    = 250000
  END_SOUNDID*      = 300000
  START_THREADID*   = 300000
  END_THREADID*     = 8000000
  START_CALLBACKID* = 8000000
  END_CALLBACKID*   = 10000000

proc isBetween(id: int, startId, endId: int): bool {.inline.} =
  id >= startId and id < endId

proc isThread*(id: int): bool {.inline.} =
  isBetween(id, START_THREADID, END_THREADID)

proc isRoom*(id: int): bool =
  isBetween(id, START_ROOMID, END_THREADID)

proc isActor*(id: int): bool =
  isBetween(id, START_ACTORID, END_ACTORID)

proc isObject*(id: int): bool =
  isBetween(id, START_OBJECTID, END_OBJECTID)

proc isSound*(id: int): bool =
  isBetween(id, START_SOUNDID, END_SOUNDID)
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
  
var
  gRoomId = START_ROOMID
  gActorId = START_ACTORID
  gObjId = START_OBJECTID
  gSoundDefId = START_SOUNDDEFID
  gSoundId = START_SOUNDID
  gThreadId = START_THREAD_ID
  gCallbackId = START_CALLBACKID
  gLightId = START_LIGHTID

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

proc isLight*(id: int): bool =
  isBetween(id, START_LIGHTID, END_LIGHTID)

proc isCallback*(id: int): bool =
  isBetween(id, START_CALLBACKID, END_CALLBACKID)

proc newRoomId*(): int =
  result = gRoomId
  gRoomId += 1

proc newObjId*(): int =
  result = gObjId
  gObjId += 1

proc newActorId*(): int =
  result = gActorId
  gActorId += 1

proc newSoundDefId*(): int =
  result = gSoundDefId
  gSoundDefId += 1

proc newSoundId*(): int =
  result = gSoundId
  gSoundId += 1

proc newThreadId*(): int =
  result = gThreadId
  gThreadId += 1

proc newCallbackId*(): int =
  result = gCallbackId
  gCallbackId += 1

proc setCallbackId*(id: int) =
  gCallbackId = id

proc newLightId*(): int =
  result = gLightId
  gLightId += 1

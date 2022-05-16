type EventManager* = ref object of RootObj

var gEventMgr*: EventManager

method trig*(self: EventManager, name: string) {.base, locks: "unknown".} =
  discard

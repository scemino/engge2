import sqnim
import ids
import ../script/squtils
import ../script/vm

type Callback* = ref object of RootObj
  id*: int
  name: string
  args: seq[HSQOBJECT]
  duration: float
  elapsed: float

proc newCallback*(duration: float, name: string, args: seq[HSQOBJECT]): Callback =
  result = Callback(id: newCallbackId(), name: name, args: args, duration: duration)

proc call(self: Callback) =
  gVm.v.call(gVm.v.rootTbl(), self.name, self.args)

proc update*(self: Callback, elapsed: float): bool =
  self.elapsed += elapsed
  result = self.elapsed > self.duration;
  if result:
    self.call()
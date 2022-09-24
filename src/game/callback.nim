import sqnim
import ../script/squtils

type Callback* = ref object of RootObj
  id*: int
  name*: string
  args*: seq[HSQOBJECT]
  duration*: float
  elapsed*: float

proc newCallback*(id: int, duration: float, name: string, args: seq[HSQOBJECT]): Callback =
  result = Callback(id: id, name: name, args: args, duration: duration)

proc call(self: Callback) =
  call(self.name, self.args)

proc update*(self: Callback, elapsed: float): bool =
  self.elapsed += elapsed
  result = self.elapsed > self.duration
  if result:
    self.call()
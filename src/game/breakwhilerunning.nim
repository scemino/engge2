import std/strformat
import task
import utils
import thread

type BreakWhileRunning = ref object of Task
  parentId, id: int

proc newBreakWhileRunning*(parentId, id: int): BreakWhileRunning =
  BreakWhileRunning(parentId: parentId, id: id, name: fmt"breakwhilerunning({id})")

method update*(self: BreakWhileRunning, elapsed: float): bool =
  let t = thread(self.id)
  if not t.isNil:
    return false
  let pt = thread(self.parentId)
  if not pt.isNil:
    echo "Resume task: " & $self.parentId
    pt.resume()
  true
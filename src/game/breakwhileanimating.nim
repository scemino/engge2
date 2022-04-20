import std/logging
import std/strformat
import task
import utils
import thread
import ../game/room

type BreakWhileAnimating = ref object of Task
  parentId: int
  obj: Object

proc newBreakWhileAnimating*(parentId: int, obj: Object): BreakWhileAnimating =
  BreakWhileAnimating(parentId: parentId, obj: obj, name: fmt"BreakWhileAnimating({obj.name})")

method update*(self: BreakWhileAnimating, elapsed: float): bool =
  if not self.obj.nodeAnim.isNil and self.obj.nodeAnim.enabled:
    return false
  let pt = thread(self.parentId)
  if not pt.isNil:
    debug "Resume task: " & $self.parentId
    pt.resume()
  true
import std/logging
import task
import utils
import thread

type 
  Predicate* = proc (): bool
  BreakWhileCond = ref object of Task
    parentId: int
    cond: Predicate

proc newBreakWhileCond*(parentId: int, name: string, cond: Predicate): BreakWhileCond =
  BreakWhileCond(parentId: parentId, name: name, cond: cond)

method update*(self: BreakWhileCond, elapsed: float): bool =
  if self.cond():
    return false
  let pt = thread(self.parentId)
  if not pt.isNil:
    debug "Resume task: " & $self.parentId
    pt.resume()
  true
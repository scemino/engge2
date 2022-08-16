import std/times
import nimyggpack

type
  time_t {.importc: "time_t", header: "<time.h>".} = int64 
  TM {.importc: "struct tm", header: "<time.h>".} = object
    tm_sec: cint
    tm_min: cint
    tm_hour: cint
    tm_mday: cint
    tm_mon: cint
    tm_year: cint
    tm_wday: cint
    tm_yday: cint
    tm_isdst: cint

proc strftime(str: cstring, count: csize_t, format: cstring, time: ptr TM): csize_t {.importc, header: "<time.h>".}
proc localtime(time: ptr time_t): ptr TM {.importc, header: "<time.h>".}

proc fmtTimeLikeC*(time: Time, format: string): string =
  let t = cast[time_t](toUnix(time))
  var tm = localtime(t.unsafeAddr)
  var buf = newSeq[byte](64)
  discard strftime(cast[cstring](buf[0].addr), buf.len.cuint, format, tm)
  newString(buf)

when isMainModule:
  echo fmtTimeLikeC(getTime(), "%b %d at %H:%M")
  var buf: array[120, char]
  var str = cast[cstring](buf[0].addr)
  discard snprintf(str, 120, "%d %d", 1, 2)
  echo str

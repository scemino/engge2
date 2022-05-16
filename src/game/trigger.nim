type Trigger* = ref object of RootObj

# Trigger
method trig*(self: Trigger) {.base, locks: "unknown".} =
  discard

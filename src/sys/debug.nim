import ../libs/imgui

proc imguiRender*() =
  if igBegin("Debug"):
    igText("Hellow world")
  igEnd()

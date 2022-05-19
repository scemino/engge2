import ../libs/imgui
import debugtool

proc imguiRender*() =
  for tool in debugTools():
    tool.render()

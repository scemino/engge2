import debugtool

proc imguiRender*() =
  if gGeneralVisible:
    for tool in debugTools():
      tool.render()

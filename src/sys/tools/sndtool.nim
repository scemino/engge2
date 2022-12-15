import ../debugtool
import ../../game/engine
import ../../audio/audio
import nglib

type SoundTool = ref object of DebugTool
  visible*: bool

proc newSoundTool*(): SoundTool =
  result = SoundTool()

method render*(self: SoundTool) =
  if gEngine.isNil or not self.visible:
    return

  # count the number of active sounds
  var count = 0
  for s in gEngine.audio.sounds:
    if not s.isNil:
      inc count

  igSetNextWindowSize(ImVec2(x: 520, y: 600), ImGuiCond.FirstUseEver)
  igBegin("Sounds".cstring, addr self.visible)
  igText("# sounds: %d/%d", count, gEngine.audio.sounds.len)
  igSeparator()
    
  if igBeginTable("Threads", 8, (Borders.int or SizingFixedFit.int or Resizable.int or RowBg.int).ImGuiTableFlags):
    igTableSetupColumn("")
    igTableSetupColumn("Id")
    igTableSetupColumn("Category")
    igTableSetupColumn("Name")
    igTableSetupColumn("Loops")
    igTableSetupColumn("Volume")
    igTableSetupColumn("Pan")
    igTableSetupColumn("Status")
    igTableHeadersRow()

    for i in 0..<gEngine.audio.sounds.len:
      let sound = gEngine.audio.sounds[i]
      igTableNextRow()
      igTableNextColumn()
      igText("#%ld", i)
      if not sound.isNil:
        igTableNextColumn()
        igText("%ld", sound.id)
        igTableNextColumn()
        igText("%s", ($sound.cat).cstring)
        igTableNextColumn()
        igText("%s", sound.sndDef.name.cstring)
        igTableNextColumn()
        igText("%d", sound.chan.numLoops)
        igTableNextColumn()
        igText("%0.1f", sound.chan.vol)
        igTableNextColumn()
        igText("%0.1f", sound.pan)
        igTableNextColumn()
        igText("%s", ($status(sound.chan)).cstring)
        igSameLine()
        if igSmallButton("STOP"):
          gEngine.audio.fadeOut(sound)
    
    igEndTable()

  igEnd()

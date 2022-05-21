import std/strutils
import std/strformat
import ../../libs/imgui

type Console* = ref object of RootObj
  inputBuf: array[256, char]
  items: seq[string]
  history: seq[string]
  commands: seq[string]
  historyPos: int             # -1: new line, 0..History.Size-1 browsing history.
  filter: ImGuiTextFilter
  autoScroll: bool
  scrollToBottom: bool

proc newConsole*(): Console =
  Console(historyPos: -1, commands: @["HELP", "HISTORY", "CLEAR"], autoScroll: true)

proc clearLog*(self: Console) =
  self.items.setLen 0

proc addLog*(self: Console, msg: string) =
  self.items.add(msg)

proc execCommand(self: Console, cmdline: string) =
  self.addLog(fmt"> {cmdline}")

  # Insert into history. First find match and delete it so it can be pushed to the back. This isn't trying to be smart or optimal.
  self.historyPos = -1
  for i in countdown(self.history.len-1, 0):
    if self.history[i] == cmdline:
      self.history.del i
      break
  self.history.add(cmdline)

  # Process command
  if cmdline == "CLEAR":
    self.clearLog()
  elif cmdline == "HELP":
    self.addLog("Commands:")
    for cmd in self.commands:
      self.addLog(fmt"- {cmd}")
  elif cmdline == "HISTORY":
    let first = self.history.len - 10
    let start = if first > 0: first else: 0
    for i in start..<self.history.len:
      self.addLog(fmt"{i:03}: {self.history[i]}")
  else:
    self.addLog(cmdline)

  # On commad input, we scroll to bottom even if AutoScroll==false
  self.scrollToBottom = true

proc cmpIgnoreCase(str1, str2: string, len: int): int =
  echo fmt"cmpIgnoreCase({str1},{str2},{len})"
  for i in 0..<len:
    let d = toUpperAscii(str2[i]).ord - toUpperAscii(str1[i]).ord
    echo fmt"  {toUpperAscii(str2[i])} - {toUpperAscii(str1[i])} = {d}"
    if d != 0:
      return d

proc textEditCallback(self: Console, data: ptr ImGuiInputTextCallbackData): int32 =
  case data.eventFlag:
  of ImGuiInputTextFlags.CallbackCompletion:
    # Example of TEXT COMPLETION

    # Locate beginning of current word
    let word_end = data.cursorPos
    var word_start = data.cursorPos
    while word_start > 0:
      let c = data.buf[word_start-1]
      if c == ' ' or c == '\t' or c == ',' or c == ';':
        break
      word_start -= 1

    let command = ($data.buf).substr(word_start, word_end - word_start)

    # Build a list of candidates
    echo fmt"commands = {self.commands}"
    var candidates: seq[string]
    for cmd in self.commands:
      echo fmt"test command {command} with {cmd}"
      if cmpIgnoreCase(command, cmd, word_end - word_start) == 0:
        candidates.add(cmd)

    if candidates.len == 0:
      # No match
      self.addLog(fmt"No match for '{command}'!")
    elif candidates.len == 1:
      # Single match. Delete the beginning of the word and replace it entirely so we've got nice casing
      data.deleteChars(word_start, word_end - word_start)
      data.insertChars(data.cursorPos, candidates[0])
      data.insertChars(data.cursorPos, " ")
    else:
      # Multiple matches. Complete as much as we can, so inputing "C" will complete to "CL" and display "CLEAR" and "CLASSIFY"
      var match_len = word_end - word_start
      while true:
        var c = '\0'
        var all_candidates_matches = true
        for i in 0..<candidates.len:
          if i == 0:
            c = toUpperAscii(candidates[i][match_len])
          elif c == '\0' or c != toUpperAscii(candidates[i][match_len]):
            all_candidates_matches = false
        if not all_candidates_matches:
          break
        match_len += 1'i32

      if match_len > 0:
        data.deleteChars(word_start, word_end - word_start)
        data.insertChars(data.cursorPos, candidates[0], cast[cstring](candidates[0][match_len].addr))

      # List matches
      self.addLog("Possible matches:")
      for candidate in candidates:
        self.addLog(fmt"- {candidate}")
  of ImGuiInputTextFlags.CallbackHistory:
    # Example of HISTORY
    let prev_history_pos = self.historyPos
    if data.eventKey == ImGuiKey.UpArrow:
      if self.historyPos == -1:
        self.historyPos = self.history.len - 1
      elif self.historyPos > 0:
        self.historyPos -= 1
    elif data.eventKey == ImGuiKey.DownArrow:
      if self.historyPos != -1:
        self.historyPos += 1
        if self.historyPos >= self.history.len:
          self.historyPos = -1

    # A better implementation would preserve the data on the current input line along with cursor position.
    if prev_history_pos != self.historyPos:
      let history_str = if self.historyPos >= 0: self.history[self.historyPos] else: ""
      data.deleteChars(0, data.bufTextLen)
      data.insertChars(0, history_str)
  else:
    discard
  return 0

proc textEditCallbackStub(data: ptr ImGuiInputTextCallbackData): int32 {.cdecl.} = # In C++11 you are better off using lambdas for this sort of forwarding callbacks
  var console = cast[ptr Console](data.userData)
  return console[].textEditCallback(data)

proc draw*(self: Console, p_open: ptr bool) =
  igSetNextWindowSize(ImVec2(x: 520, y: 600), ImGuiCond.FirstUseEver)
  if not igBegin("Console", p_open):
    igEnd()
    return

  # As a specific feature guaranteed by the library, after calling Begin() the last Item represent the title bar. So e.g. IsItemHovered() will return true when hovering the title bar.
  # Here we create a context menu only available from the title bar.
  if igBeginPopupContextItem():
    if igMenuItem("Close Console"):
      p_open[] = false
    igEndPopup()
  
  igTextWrapped("Enter 'HELP' for help, press TAB to use text completion.")
  if igSmallButton("Clear"):
    self.clearLog()
  igSameLine()
  let copy_to_clipboard = igSmallButton("Copy")
  igSeparator()

  # Options menu
  if igBeginPopup("Options"):
    igCheckbox("Auto-scroll", addr self.autoScroll)
    igEndPopup()

  # Options, Filter
  if igButton("Options"):
    igOpenPopup("Options")
  igSameLine()
  #Filter.Draw("Filter (\"incl,-excl\") (\"error\")", 180)
  igSeparator()

  let footer_height_to_reserve =
      igGetStyle().itemSpacing.y + igGetFrameHeightWithSpacing() # 1 separator, 1 input text
  igBeginChild("ScrollingRegion",
                    ImVec2(x: 0, y: -footer_height_to_reserve),
                    false,
                    ImGuiWindowFlags.HorizontalScrollbar) # Leave room for 1 separator + 1 InputText
  if igBeginPopupContextWindow():
    if igSelectable("Clear"):
      self.clearLog()
    igEndPopup()

  # Display every line as a separate entry so we can change their color or add custom widgets. If you only want raw text you can use ImGui::TextUnformatted(log.begin(), log.end())
  # NB- if you have thousands of entries this approach may be too inefficient and may require user-side clipping to only process visible items.
  # You can seek and display only the lines that are visible using the ImGuiListClipper helper, if your elements are evenly spaced and you have cheap random access to the elements.
  # To use the clipper we could replace the 'for (int i = 0 i < Items.Size i++)' loop with:
  #     ImGuiListClipper clipper(Items.Size)
  #     while (clipper.Step())
  #         for (int i = clipper.DisplayStart i < clipper.DisplayEnd i++)
  # However, note that you can not use this code as is if a filter is active because it breaks the 'cheap random-access' property. We would need random-access on the post-filtered list.
  # A typical application wanting coarse clipping and filtering may want to pre-compute an array of indices that passed the filtering test, recomputing this array when user changes the filter,
  # and appending newly elements as they are inserted. This is left as a task to the user until we can manage to improve this example code!
  # If your items are of variable size you may want to implement code similar to what ImGuiListClipper does. Or split your data into fixed height items to allow random-seeking into your list.
  igPushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(x: 4, y: 1)) # Tighten spacing

  if copy_to_clipboard:
    igLogToClipboard()

  for item in self.items:
    var it = item
    if not passFilter(addr self.filter, item):
      continue

    # Normally you would store more information in your item (e.g. make Items[] an array of structure, store color/type etc.)
    var pop_color = false
    if item.contains("[error]"):
      it = item.substr(7)
      igPushStyleColor(ImGuiCol.Text, ImVec4(x: 1.0f, y: 0.4f, z: 0.4f, w: 1.0f))
      pop_color = true
    elif item.contains("> "):
      igPushStyleColor(ImGuiCol.Text, ImVec4(x: 1.0f, y: 0.8f, z: 0.6f, w: 1.0f))
      pop_color = true
    igTextUnformatted(it)
    if pop_color:
      igPopStyleColor()

  if copy_to_clipboard:
    igLogFinish()

  if self.scrollToBottom or (self.autoScroll and igGetScrollY() >= igGetScrollMaxY()):
    igSetScrollHereY(1.0f)
  self.scrollToBottom = false

  igPopStyleVar()
  igEndChild()
  igSeparator()

  # Command-line
  var reclaim_focus = false
  if igInputText("Input",
                       cast[cstring](self.inputBuf[0].addr),
                       self.inputBuf.len.uint,
                       (ImGuiInputTextFlags.EnterReturnsTrue.int or ImGuiInputTextFlags.CallbackCompletion.int or ImGuiInputTextFlags.CallbackHistory.int).ImGuiInputTextFlags,
                       textEditCallbackStub,
                       self.unsafeAddr):
    var s = ($cast[cstring](self.inputBuf[0].addr))
    s.removeSuffix(" ")
    if s.len > 0:
      self.execCommand(s)
    s = ""
    reclaim_focus = true

  # Auto-focus on window apparition
  igSetItemDefaultFocus()
  if reclaim_focus:
    igSetKeyboardFocusHere(-1)  # Auto focus previous widget

  igEnd()

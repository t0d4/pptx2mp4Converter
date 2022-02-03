import std/[
  terminal
]

template withProgressDisplay*(silent, bool, message: string, codeBlock: untyped): untyped =
  try:
    if not silent:
      stdout.styledWriteLine(message, styleBlink, fgYellow, "processing...", resetStyle)
    codeBlock
    if not silent:
      cursorUp(1)
      eraseLine()
      stdout.styledWriteLine(message, styleBright, fgGreen, "done", resetStyle)
  except MediaError as e:
    if not silent:
      cursorUp(1)
      eraseLine()
      stdout.styledWriteLine(message, styleBright, fgRed, "failed", resetStyle)
    stderr.styledWriteLine(fgRed, e.msg, resetStyle)
    system.quit(1)
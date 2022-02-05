# Visualizes the process and handles error
template withProgressDisplayAndErrorHandling*(shouldBeSilent: bool, message: string, codeBlock: untyped): untyped =
  try:
    if not silent:
      stdout.styledWriteLine(message, styleBlink, fgYellow, " processing...", resetStyle)
    codeBlock
    if not silent:
      # Rewrite the message, replacing "processing..." with "done."
      cursorUp(1)
      eraseLine()
      stdout.styledWriteLine(message, styleBright, fgGreen, " done", resetStyle)
  except MediaError as e:
    if not silent:
      cursorUp(1)
      eraseLine()
      stdout.styledWriteLine(message, styleBright, fgRed, " failed", resetStyle)
    stderr.styledWriteLine(fgRed, "Error: ", e.msg, resetStyle)
    system.quit(1)
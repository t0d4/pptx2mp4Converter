# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import parseopt2
import version
import zip/zipfiles

let doc = """
A simple CLI tool to convert a pptx(or ppsx) file to a mp4 video file.

Usage:
  pptx2mp4conv <filename>...
  pptx2mp4conv (-h | --help)
  pptx2mp4conv --chkdeps
  pptx2mp4conv --version

Options:
  -h --help     Show this screen.
  --version     Show version.
  --speed=<kn>  Speed in knots [default: 10].
  --moored      Moored (anchored) mine.
  --drifting    Drifting mine.
"""

when isMainModule:

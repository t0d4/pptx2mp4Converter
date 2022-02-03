import
  std/os
  std/strformat
  std/strutils
  system
  std/terminal
  zip/zipfiles

import
  docopt

import
  preparations
  helpers
  myTemplates


const NimblePkgVersion {.strdefine.} = "Unknown"
const Doc = "pptx2mp4Converter v" & NimblePkgVersion & "\n" & 
"""
A simple CLI tool to convert a pptx(or ppsx) file to a mp4 video file.

Usage:
  pptx2mp4conv <filename> [options]
  pptx2mp4conv --chkdeps
  pptx2mp4conv (-h | --help)
  pptx2mp4conv --version

Options:
  -o FILE --output=FILE  Output file name.
  -h --help     Show this screen.
  --version  Show version.
  --chkdeps     Check whether all dependencies are installed.
  --duration-of-silent-slide=<s>  Duration of silent slide in seconds [default: 5].
  --libreoffice-executable=<path>  Path to libreoffice executable. (See the Note below)
  --silent     Do not show messages.

Note:
  Since Libreoffice executables have various namings (e.g. soffice, libreoffice, libreoffice7.2, etc.),
  this program sometimes fails to find the correct executable. In that case, you can specify the path to
  the executable using the --libreoffice-executable option. Be careful that this option deactivates dependency checking.
"""

when isMainModule:
  let tmpDir: string = getTempDir.joinPath("pptx2mp4conv")

  let args = docopt(Doc, version = "pptx2mp4Converter " & NimblePkgVersion)

  if args["--chkdeps"]:
    discard checkDependencies(verbose=true)
    system.quit(0)

  let pptxFile: string = $args["<filename>"]
  let durationOfSilentSlide: int = parseInt($args["--duration-of-silent-slide"])
  let outputFile: string = 
    if args["--output"]:
      if ($args["--output"]).parentDir.dirExists:
        $args["--output"]
      else:
        stderr.styledWriteLine(fgRed, "Error: Output directory does not exist: " & ($args["--output"]).parentDir(), resetStyle)
        system.quit(1)
    else:
      ($args["<filename>"]).changeFileExt("mp4")
  let libreofficeExecutable: string = 
    if args["--libreoffice-executable"]:
      if ($args["--libreoffice-executable"]).fileExists:
        $args["--libreoffice-executable"]
      else:
        stderr.styledWriteLine(fgRed, "Error: Specified executable does not exist: " & $args["--libreoffice-executable"], resetStyle)
        system.quit(1)
    else:
      "soffice"
  let silent: bool = args["--silent"].toBool

  # Run dependency checker if libreoffice executable is not explicitly specified.
  if not args["--libreoffice-executable"]:
    if checkDependencies(verbose=false) == 1:
      stderr.styledWriteLine(fgRed, "Error: Dependencies are not met.", resetStyle)
      stderr.styledWriteLine(fgRed, "Run \"./pptx2mp4conv --chkdeps\" to find out lacking packages", resetStyle)
      system.quit(1)

  var z: ZipArchive
  if not z.open(pptxFile):
    stderr.styledWriteLine(fgRed, "Error: Failed to extract pptx: " & pptxFile, resetStyle)
    system.quit(1)
  let extractedPPTXDir = tmpDir.joinPath("extracted")
  z.extractAll(extractedPPTXDir)

  
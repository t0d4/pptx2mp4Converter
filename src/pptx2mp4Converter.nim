import std/[
  algorithm,
  exitprocs,
  os,
  sequtils,
  strutils,
  sugar,
  terminal
]

import
  docopt,
  zip/zipfiles

import
  preparations,
  helpers,
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

const TmpDirRoot: string = getTempDir().joinPath("pptx2mp4conv")
const ExtractedPPTXDir: string = TmpDirRoot.joinPath("extracted")
const SlideXMLDir: string = ExtractedPPTXDir.joinPath("ppt", "slides")
const RelationXMLDir: string = ExtractedPPTXDir.joinPath("ppt", "slides", "_rels")
const MediaDir: string = ExtractedPPTXDir.joinPath("ppt", "media")
const TmpVideoDir: string = TmpDirRoot.joinPath("videos")
const TmpVideoFileListPath: string = TmpVideoDir.joinPath("videofiles.txt")
const TmpPictureDir: string = TmpDirRoot.joinPath("pictures")
const TmpPictureFilepathTemplate: string = TmpPictureDir.joinPath("slide")  # This constant shouldn't be changed unless you update the implementation of cmpUsingFilename()
const ModifiedPPTXFilepath: string = TmpDirRoot.joinPath("new.pptx")
const ConvertedPDFFilepath: string = ModifiedPPTXFilepath.changeFileExt("pdf")
const SilentM4AFilepath: string = TmpDirRoot.joinPath("silent.m4a")


when isMainModule:
  # Delete the temporary directory if it exists, and register removal at the exit of this program
  let deleteTempDir = generateTempDirRemover(TmpDirRoot)
  deleteTempDir()
  addExitProc(deleteTempDir)

  # Create temporary workspaces. Watch out for the order
  TmpDirRoot.createDir()
  ExtractedPPTXDir.createDir()
  TmpVideoDir.createDir()
  TmpPictureDir.createDir()

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

  # Extract the pptx file to the workspace
  block extractPPTX:
    var originalPPTX: ZipArchive
    defer: originalPPTX.close()
    if not originalPPTX.open(pptxFile):
      stderr.styledWriteLine(fgRed, "Error: Failed to extract pptx: " & pptxFile, resetStyle)
      system.quit(1)
    originalPPTX.extractAll(ExtractedPPTXDir)
    sleep(SleepLengthBetweenIOOperations)

  # Delete unnecessary audio icons from slides and output a modified pptx file
  let slideXMLs: seq[string] = sequtils.toSeq(walkFiles(SlideXMLDir.joinPath("slide*.xml")))
  let slideCount: int = slideXMLs.len
  withProgressDisplayAndErrorHandling(
    shouldBeSilent = silent,
    message = "1/5  Modifying a copied version of the pptx file:"
  ):
    for slideXML in slideXMLs:
      slideXML.deleteUnwantedAudioIcon()

    block makeModifiedPPTX:
      var modifiedPPTX: ZipArchive
      defer: modifiedPPTX.close()
      if not modifiedPPTX.open(ModifiedPPTXFilepath, fmWrite):
        raise newException(MediaError, "Failed to make a modified pptx file in the temporary directory")
      var
        tokens: seq[string]
        filepathInArchive: string
      for file in walkDirRec(ExtractedPPTXDir, yieldFilter={pcFile}):
        tokens = file.split($DirSep)
        # tokens is an array like ["", "tmp", "pptx2mp4conv", "extracted", "ppt", "slides", "slide1.xml"]
        # so filepath in the zip archive will start from 4th element in the array
        filepathInArchive = tokens[4..^1].join($DirSep)
        modifiedPPTX.addFile(filepathInArchive, file)
      sleep(SleepLengthBetweenIOOperations)

  # Convert the modified pptx file into a pdf file, and then convert the pdf file into png files
  var pngFilepaths: seq[string]
  withProgressDisplayAndErrorHandling(
    shouldBeSilent = silent,
    message = "2/5  Converting the modified pptx file into png files:"
  ):
    ModifiedPPTXFilepath.convertIntoPDF(
      libreofficeExecutable = libreofficeExecutable,
      saveDir = ConvertedPDFFilepath.parentDir
    )
    pngFilepaths = ConvertedPDFFilepath.convertIntoPNGs(
      saveTemplate = TmpPictureFilepathTemplate
    )
    pngFilepaths.sort(cmpUsingFilename)

  # Collect audio filepaths from slide relationship XML and 
  # create a silent audio file for silent slides.
  var m4aFilepaths: seq[string]
  withProgressDisplayAndErrorHandling(
    shouldBeSilent = silent,
    message = "3/5  Collecting audio information and preparing audio files:"
  ):
    var slideRelationXMLs: seq[string] = sequtils.toSeq(walkFiles(RelationXMLDir.joinPath("slide*.xml.rels")))
    slideRelationXMLs.sort(cmpUsingFilename)

    for slideRelationXML in slideRelationXMLs:
      m4aFilepaths.add(slideRelationXML.seekAudioForTheSlide(
        mediaDirpath = MediaDir,
        defaultAudioFilepath = SilentM4AFilepath
      ))

    # Abort if no audio file is found
    if m4aFilepaths.len == 0:
      raise newException(MediaError, "No audio file is found in the pptx file.")

    createSilentAudioFile(
      duration = durationOfSilentSlide,
      saveTo = SilentM4AFilepath
    )

  # Check if the number of slide pngs is equal to the number of slide audio files (including silent audio)
  if pngFilepaths.len != m4aFilepaths.len:
    stderr.styledWriteLine(fgRed, "Error: Something went wrong when trying to collect png files and m4a files.", resetStyle)
    system.quit(1)

  # Merge audio files and png files into video files for each slide
  let tmpVideoFilepaths: seq[string] = collect(newSeq):
      for slidenum in 1..slideCount: TmpVideoDir.joinPath("slide" & $slidenum & ".mp4")
  withProgressDisplayAndErrorHandling(
    shouldBeSilent = silent,
    message = "4/5  Merging audio files and png files into temporary video files:"
  ):
    for index in 0..<slideCount:
      createVideoFromPNGAndM4A(
        pngFilepath = pngFilepaths[index],
        m4aFilepath = m4aFilepaths[index],
        saveTo = tmpVideoFilepaths[index]
      )

  # Merge all temporary video files into one video file
  try:
    removeFile(outputFile)
  except OSError:
    stderr.styledWriteLine(fgRed, "Output file already exists, and failed to delete it: " & outputFile, resetStyle)
    quit(1)

  withProgressDisplayAndErrorHandling(
    shouldBeSilent = silent,
    message = "5/5  Merging all temporary video files into one video file:"
  ):
    tmpVideoFilepaths.concatenateVideos(
      tmpVideoFileListPath = TmpVideoFileListPath,
      saveTo = outputFile
    )
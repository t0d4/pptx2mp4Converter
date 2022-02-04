import std/[
  algorithm,
  enumerate,
  os,
  osproc,
  sequtils,
  strformat,
  strutils,
  terminal,
  xmlparser,
  xmltree,
  wrapnils
  ]

type
  MediaError* = object of Exception


proc generateTempDirRemover*(tmpDir: string): (proc(none: void): void) =
  result = proc(none: void): void =
    try:
      removeDir(tmpDir)
    except OSError:
      stderr.styledWriteLine(fgRed, "Could not delete temporary directory: " & tmpDir, resetStyle)


proc deleteUnwantedAudioIcon*(xmlFilepath: string): void =
  var isXMLModified: bool = false
  let rootNode: XmlNode = xmlparser.loadXml(xmlFilepath)
  let graphicElementsParentNode: XmlNode = rootNode
    .child("p:cSld")
    .child("p:spTree")
  for (index, graphicElementNode) in enumerate(graphicElementsParentNode):
    if graphicElementNode.tag == "p:pic":
      var nameAttribute = ?.graphicElementNode
        .child("p:nvPicPr")
        .child("p:cNvPr")
        .attr("name")
      if nameAttribute == "録音したサウンド":
        # delete() deletes {index}'th child of {graphicElementsParentNode} 
        graphicElementsParentNode.delete(index)
        isXMLModified = true
  if isXMLModified:
    let xmlFileObject = open(xmlFilepath, fmWrite)
    defer: xmlFileObject.close()
    xmlFileObject.writeLine("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>")
    xmlFileObject.write($rootNode)


proc cmpUsingFilename*(filepath1, filepath2: string): int =
  let filename1: string = filepath1.extractFilename()
  let filename2: string = filepath2.extractFilename()
  result = cmp(filename1, filename2)


proc seekAudioForTheSlide*(xmlFilepath, mediaDirpath, defaultAudioFilepath: string): string =
  let rootNode: XmlNode = xmlparser.loadXml(xmlFilepath)
  var mediaFilepath: string
  for relationshipNode in rootNode:
    mediaFilepath = ?.relationshipNode.attr("Target")
    if mediaFilepath.endsWith(".m4a"):
      return mediaDirpath.joinPath(mediaFilepath.extractFilename())
  return defaultAudioFilepath


proc createSilentAudioFile*(duration: int, saveTo: string): void {.raises: [MediaError, ValueError].} =
  let returnCode = execCmd("ffmpeg -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -t {duration} {saveTo} 2>&1 /dev/null".fmt)
  if returnCode != 0:
    raise newException(MediaError, "Failed to create silent audio file")


proc convertIntoPDF*(pptxFilepath: string, libreofficeExecutable: string, saveDir: string): void {.raises: [MediaError, ValueError].} =
  let returnCode = execCmd("{libreofficeExecutable} --headless --convert-to pdf {pptxFilepath} --outdir {saveDir} 2>&1 /dev/null".fmt)
  if returnCode != 0:
    raise newException(MediaError, "Failed to convert pptx into pdf")


proc convertIntoPNGs*(pdfFilepath: string, saveDir: string): seq[string] {.raises: [MediaError, ValueError].}  =
  let returnCode = execCmd("pdftoppm -q -png {pdfFilepath} {saveDir} 2>&1 /dev/null".fmt)
  if returnCode != 0:
    raise newException(MediaError, "Failed to convert pdf into png files")
  else:
    result = toSeq(walkDirs(saveDir.joinPath("*.png")))
    result.sort(cmpUsingFilename)


proc createVideoFromPNGAndM4A*(pngFilepath: string, m4aFilepath: string, saveTo: string): void {.raises: [MediaError, ValueError].} =
  let returnCode = execCmd("ffmpeg -loop 1 -framerate 1 -i {pngFilepath} -i {m4aFilepath} -c:v libx264 -tune stillimage -acodec copy -pix_fmt yuv420p -shortest {saveTo} 2>&1".fmt)
  if returnCode != 0:
    raise newException(MediaError, "Failed to combine png and m4a into mp4")


proc concatenateVideos*(videoFilepaths: seq[string], tmpVideoFileListPath: string, saveTo: string): void {.raises: [MediaError, ValueError, IOError].} =
  var videoFileList = open(tmpVideoFileListPath, fmWrite)
  defer: videoFileList.close()
  block makeFileList:
    for videoFilepath in videoFilepaths:
      videoFileList.writeLine("file " & videoFilepath)
  let returnCode = execCmd("ffmpeg -f concat -i {tmpVideoFileListPath} -c copy {saveTo} 2>&1".fmt)
  if returnCode != 0:
    raise newException(MediaError, "Failed to concatenate videos")
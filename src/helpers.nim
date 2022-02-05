import std/[
  enumerate,
  nre,
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

const SleepLengthBetweenIOOperations* = 2000

type
  MediaError* = object of CatchableError


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
  var nonVisualProperty: XmlNode
  var hlinkClickNode: XmlNode
  var nameAttribute: string
  var actionAttribute: string

  for (index, graphicElementNode) in enumerate(graphicElementsParentNode):
    if graphicElementNode.tag == "p:pic":
    # tags in slide.xml which specify an audio file to embed have various names.
    # So we need to check for all patterns. 
      nonVisualProperty = graphicElementNode
        .child("p:nvPicPr")
        .child("p:cNvPr")
      nameAttribute = ?.(nonVisualProperty).attr("name")
      hlinkClickNode = (nonVisualProperty).child("a:hlinkClick")
      if hlinkClickNode != nil:
        actionAttribute = hlinkClickNode.attr("action")

      if nameAttribute == "録音したサウンド" or actionAttribute == "ppaction://media":
        # delete() deletes {index}'th child of {graphicElementsParentNode}
        graphicElementsParentNode.delete(index)
        isXMLModified = true
  if isXMLModified:
    let xmlFileObject = open(xmlFilepath, fmWrite)
    defer: xmlFileObject.close()
    xmlFileObject.writeLine("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>")
    xmlFileObject.write($rootNode)


proc cmpUsingFilename*(filepath1, filepath2: string): int =
  let filenum1: int = filepath1.extractFilename().find(re"(?<=slide-|slide)\d+").get().captures[-1].parseInt()
  let filenum2: int = filepath2.extractFilename().find(re"(?<=slide-|slide)\d+").get().captures[-1].parseInt()
  result = cmp(filenum1, filenum2)


proc seekAudioForTheSlide*(xmlFilepath, mediaDirpath, defaultAudioFilepath: string): string =
  let rootNode: XmlNode = xmlparser.loadXml(xmlFilepath)
  var mediaFilepath: string
  for relationshipNode in rootNode:
    mediaFilepath = ?.(relationshipNode).attr("Target")
    if mediaFilepath.endsWith(".m4a"):
      return mediaDirpath.joinPath(mediaFilepath.extractFilename())
  return defaultAudioFilepath


proc createSilentAudioFile*(duration: int, saveTo: string): void {.raises: [MediaError, ValueError].} =
  let returnCode = execCmd("ffmpeg -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -t {duration} {saveTo} > /dev/null 2>&1".fmt)
  if returnCode != 0:
    raise newException(MediaError, "Failed to create silent audio file")
  sleep(SleepLengthBetweenIOOperations)


proc convertIntoPDF*(pptxFilepath: string, libreofficeExecutable: string, saveDir: string): void {.raises: [MediaError, ValueError].} =
  let returnCode = execCmd("{libreofficeExecutable} --headless --convert-to pdf:impress_pdf_Export {pptxFilepath} --outdir {saveDir} > /dev/null 2>&1".fmt)
  if returnCode != 0:
    raise newException(MediaError, "Failed to convert pptx into pdf")
  sleep(SleepLengthBetweenIOOperations)


proc convertIntoPNGs*(pdfFilepath: string, saveTemplate: string): seq[string] {.raises: [MediaError, ValueError].} =
  let returnCode = execCmd("pdftoppm -q -png {pdfFilepath} {saveTemplate} > /dev/null 2>&1".fmt)
  if returnCode != 0:
    raise newException(MediaError, "Failed to convert pdf into png files")
  else:
    result = sequtils.toSeq(walkFiles(saveTemplate.parentDir.joinPath("*.png")))
  sleep(SleepLengthBetweenIOOperations)


proc createVideoFromPNGAndM4A*(pngFilepath: string, m4aFilepath: string, saveTo: string): void {.raises: [MediaError, ValueError].} =
  let returnCode = execCmd("ffmpeg -loop 1 -framerate 1 -i {pngFilepath} -i {m4aFilepath} -c:v libx264 -tune stillimage -acodec copy -pix_fmt yuv420p -vf \"scale=trunc(iw/2)*2:trunc(ih/2)*2\" -shortest {saveTo} > /dev/null 2>&1".fmt)
  if returnCode != 0:
    raise newException(MediaError, "Failed to combine png and m4a into mp4")
  sleep(SleepLengthBetweenIOOperations)


proc concatenateVideos*(videoFilepaths: seq[string], tmpVideoFileListPath: string, saveTo: string): void {.raises: [MediaError, ValueError, IOError].} =
  var videoFileList = open(tmpVideoFileListPath, fmWrite)
  block makeFileList:
    var line: string
    for videoFilepath in videoFilepaths:
      line = "file " & videoFilepath
      videoFileList.writeLine(line)
    videoFileList.close()
  let returnCode = execCmd("ffmpeg -f concat -safe 0 -i {tmpVideoFileListPath} -c copy {saveTo} > /dev/null 2>&1".fmt)
  if returnCode != 0:
    raise newException(MediaError, "Failed to concatenate videos")
  sleep(SleepLengthBetweenIOOperations)
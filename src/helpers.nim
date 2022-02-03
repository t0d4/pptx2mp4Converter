import std/[
  enumerate,
  os,
  osproc,
  strformat,
  terminal,
  xmlparser,
  xmltree,
  wrapnils
  ]

type
  MediaError* = object of Exeption


proc deleteTempFiles(tmpDir: string): void =
  try:
    removeDir(tmpDir)
  except OSError:
    stderr.styledWriteLine(fgRed, "Could not delete temporary directory: " + tmpDir + "\n", resetStyle)


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


proc searchAudioInTheSlide*(xmlFilepath: string): string =
  let rootNode: XmlNode = xmlparser.loadXml(xmlFilepath)
  var mediaFilepath: string
  for relationshipNode in rootNode:
    mediaFilepath = relationshipNode.attr("Target")
    if mediaFilepath.endswith(".m4a"):
      return mediaFilepath
  return ""


proc createSilentAudioFile*(duration: int, saveTo: string) {.raises: [MediaError].}: void =
  let returnCode = execCmd("ffmpeg -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -t {duration} {saveTo} 2>&1 /dev/null".fmt)
  if returnCode != 0:
    raise MediaError("Failed to create silent audio file")


proc convertIntoPDF(pptxFilepath: string, libreofficeExecutable: string, saveDir: string) {.raises: [MediaError].}: void =
  let returnCode = execCmd("{libreofficeExecutable} --headless --convert-to pdf {pptxFilepath} --outdir {saveDir} 2>&1 /dev/null".fmt)
  if returnCode != 0:
    raise MediaError("Failed to convert pptx into pdf")


proc convertIntoPNGs(pdfFilepath: string, saveDir: string) {.raises: [MediaError].}: void =
  let returnCode = execCmd("pdftoppm -png {pdfFilepath} {saveDir}".fmt)
  if returnCode != 0:
    raise MediaError("Failed to convert pdf into png files")


proc createVideoFromPNGAndM4A*(pngFilepath: string, m4aFilepath: string, saveTo: string) {.raises: [MediaError].}: void =
  let returnCode = execCmd("ffmpeg -loop 1 -framerate 1 -i {pngFilepath} -i {m4aFilepath} -c:v libx264 -tune stillimage -acodec copy -pix_fmt yuv420p -shortest {saveTo} 2>&1".fmt)
  if returnCode != 0:
    raise MediaError("Failed to combine png and m4a into mp4")


proc concatenateVideos*(videoFilepaths: seq[string], tmpVideoFileListPath: string, saveTo: string) {.raises: [MediaError].}: void =
  videoFileList = open(tmpVideoFileListPath, fmWrite)
  defer: videoFileList.close()
  block makeFileList:
    for videoFilepath in videoFilepaths:
      videoFileList.writeLine("file " & videoFilepath)
  let returnCode = execCmd("ffmpeg -f concat -i {tmpVideoFileListPath} -c copy {saveTo} 2>&1".fmt)
  if returnCode != 0:
    raise MediaError("Failed to concatenate videos")
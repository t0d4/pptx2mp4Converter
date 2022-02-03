import
  std/os
  std/osproc
  std/sequtils
  std/strformat
  std/strutils
  std/nre

type ConversionError* = object of Exception


type PPTXFile* = ref object
  filepath: string

proc new*(_:type PPTXFile, filepath: string) {.raises: [IOError].}: PPTXFile =
  if not filepath.fileExists:
    raise newException(IOError, "File not found: " + filepath)
  return PPTXFile(
    filepath: filepath
  )

proc extract

proc `$`*(self: PPTXFile): string =
  return extractFilename(self.filepath)


type PDFFile* = ref object
  filepath: string

proc new*(_:type PDFFile, filepath: string) {.raises: [IOError].}: PDFFile =
  if not filepath.fileExists:
    raise newException(IOError, "File not found: " + filepath)
  return PDFFile(
    filepath: filepath
  )

proc `$`*(self: PDFFile): string =
  return extractFilename(self.filepath)


type XMLFile* = ref object
  filepath: string

proc new*(_:type XMLFile, filepath: string) {.raises: [IOError].}: XMLFile =
  if not filepath.fileExists:
    raise newException(IOError, "File not found: " + filepath)
  return XMLFile(
    filepath: filepath
  )

proc `$`*(self: XMLFile): string =
  return extractFilename(self.filepath)

proc getFilepath*(self: XMLFile): string =
  return self.filepath


type AudioFile* = ref object
  filepath: string
  duration: int

proc new*(_:type AudioFile, filepath: string) {.raises: [IOError].}: AudioFile =
  if not filepath.fileExists:
    raise newException(IOError, "File not found: " + filepath)
  var
    output: string,
    returnCode: int
  output, returnCode = execCmdEx("ffprobe -i {filepath}".fmt)
  let durationString: string = output.find(re"(?<=Duration:\s)\d+:\d+:\d+").get.`$`
  const calculateSecond = proc(x: seq[int]): int =
    result = 60*60*x[0] + 60*x[1] + x[2]
  let duration: int = durationString.split(":").map(parseInt).calculateSecond

  return AudioFile(
    filepath: filepath,
    duration: duration
  )

proc `$`*(self: AudioFile): string =
  return extractFilename(self.filepath)

proc getFilepath*(self: AudioFile): string =
  return self.filepath

proc getDuration*(self: AudioFile): int =
  return self.duration


type VideoFile* = ref object
  filepath: string

proc new*(_:type VideoFile, filepath: string) {.raises: [IOError].}: VideoFile =
  if not filepath.fileExists:
    raise newException(IOError, "File not found: " + filepath)
  return VideoFile(
    filepath: filepath
  )

proc `$`*(self: VideoFile): string =
  return extractFilename(self.filepath)

proc getFilepath*(self: VideoFile): string =
  return self.filepath
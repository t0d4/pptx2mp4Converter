# staticExec runs at compile time
const current_version* = staticExec(
    "nim c -r --hints:off --verbosity:0 -o:../tmp/get_version ../util/get_version.nim pptx2mp4Converter")
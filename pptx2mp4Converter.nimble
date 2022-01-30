# Package

version       = "0.1.0"
author        = "Takaaki Toda"
description   = "A simple CLI tool to convert a narration-embedded pptx into a single mp4."
license       = "MIT"
srcDir        = "src"
binDir        = "bin"
bin           = @["pptx2mp4conv"]


# Dependencies

requires "nim >= 1.6.2"
requires "docopt >= 0.6.7"
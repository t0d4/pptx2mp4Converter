import os
import nre, options, strutils
import strformat

let 
    cmdArgs = os.commandLineParams()
    pkgName = cmdArgs[0]

# Load the nimble file and extract version information
let nimbleFile = open("../{pkgName}.nimble".fmt, fmRead)
let lines = nimbleFile.readAll().split("\n")
for line in lines:
    let matched = line.match(re"(version)\s*=\s*""(\d+\.\d+\.\d+)""$")
    if matched.isSome:
        echo matched.get.captures[1]
        break
nimbleFile.close
import std/[
  osproc,
  strformat,
  terminal,
  ]

const externalCommandRequirements: array[3, string] = ["soffice", "ffmpeg", "pdftoppm"]
const externalSharedLibraryRequirements: array[1, string] = ["libzip"]

proc checkCommandExists(commandName: string, verbose: bool = true): int =
  ## Check whether a command exists.
  ## arguments:
  ##  commandName : string - name of the command to check
  ##  verbose     : bool - whether to print a message
  ## returns:
  ##  0 : if the command exists
  ##  1 : if the command does not exist
  if verbose:
    stdout.write("Searching for {commandName} command in PATH... ".fmt)
  let returnCode = execCmd("command -v {commandName} > /dev/null 2>&1".fmt)
  if returnCode == 0:
    if verbose:
      stdout.styledWriteLine(styleBright, fgGreen, "Found", resetStyle)
    result = 0
  else:
    if verbose:
      stdout.styledWriteLine(styleBright, fgRed, "Not Found", resetStyle)
    result = 1

proc checkLibraryExists(libraryName: string, verbose: bool = true): int =
  ## Check whether a library exists.
  ## arguments:
  ##  libraryName : string - name of the library to check
  ##  verbose     : bool - whether to print a message
  ## returns:
  ##  0 : if the library exists
  ##  1 : if the library does not exist
  if verbose:
    stdout.write("Searching for {libraryName} using ldconfig... ".fmt)
  let returnCode = execCmd("test -n \"$(ldconfig -p | grep {libraryName})\"".fmt)
  if returnCode == 0:
    if verbose:
      stdout.styledWriteLine(styleBright, fgGreen, "Found", resetStyle)
    result = 0
  else:
    if verbose:
      stdout.styledWriteLine(styleBright, fgRed, "Not Found", resetStyle)
    result = 1

proc checkDependencies*(verbose: bool = false): int =
  ## Check whether all dependencies are met.
  ## arguments:
  ##  verbose : bool - whether to print a message
  ## returns:
  ##  0 : if all dependencies are met
  ##  1 : if one or more dependencies are not met
  if verbose:
    stdout.write(
    "|--------------------|\n"&
    "| Dependency Checker |\n"&
    "|--------------------|\n")

  var issofficeCommandAvailable: bool = true
  result = 0
  for requirement in externalCommandRequirements:
    if checkCommandExists(commandName=requirement, verbose=verbose) == 1:
      if requirement == "soffice":
        issofficeCommandAvailable = false
      result = 1

  for requirement in externalSharedLibraryRequirements:
    if checkLibraryExists(libraryName=requirement, verbose=verbose) == 1:
      result = 1

  if verbose:
    if result == 0:
      stdout.styledWriteLine(styleBright, fgGreen, "All dependencies are met", resetStyle)
    else:
      stdout.styledWriteLine(styleBright, fgRed, "One or more dependencies are not met", resetStyle)
      if not issofficeCommandAvailable:
        stdout.styledWriteLine(
          fgYellow, 
          "Hint: If you think libreoffice is correctly installed in the system, " & 
          "please see the Note in the help message by \"./pptx2mp4Conv --help\"",
          resetStyle)
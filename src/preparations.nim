import osproc
import std/strformat
import std/terminal

const externalRequirements: array[3, string] = ["soffice", "ffmpeg", "pdftoppm"]

proc checkCommandExists(commandName: string, verbose: bool = true): int =
    ## Check whether a command exists.
    ## arguments:
    ##  commandName : string - name of the command to check
    ##  verbose     : bool - whether to print a message
    ## returns:
    ##  0 : if the command exists
    ##  1 : if the command does not exist
    if verbose:
        stdout.write("Searching for {commandName} in PATH... ".fmt)
    let returnCode = execCmd("command -v {commandName} >/dev/null 2>&1".fmt)
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

    result = 0
    for requirement in externalRequirements:
        if checkCommandExists(commandName=requirement, verbose=verbose) == 1:
            result = 1

    if verbose:
        if result == 0:
            stdout.styledWriteLine(styleBright, fgGreen, "All dependencies met", resetStyle)
        else:
            stdout.styledWriteLine(styleBright, fgRed, "One or more dependencies are not met", resetStyle)
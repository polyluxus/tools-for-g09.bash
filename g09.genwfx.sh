#!/bin/bash

scriptname=${0##*\/} # Remove trailing path
scriptname=${scriptname%.sh} # remove scripting ending (if present)

version="0.1.3"
versiondate="2017-12-24"

# A srcipt to take an input file and write a new inputfile to 
# obtain a wfx file.

#
# Print logging information and warnings nicely.
# If there is an unrecoverable error: display a message and exit.

indent ()
{
      echo -n "INFO   : " "$*"
    }


message ()
{
    echo "INFO   : " "$@"
}

warning ()
{
    echo "WARNING: " "$@"
}

fatal ()
{
    echo "ERROR  : " "$@"
    exit 1
}

# Usage and help
usage ()
{
    message "Usage: $scriptname [options] filenames(s)"
    exit 0
}

helpme ()
{
    message "There are no options yet. (work in progress)"
    message "Version: $version ($versiondate)"
    usage
    exit 0
}

getCheckpointfile ()
{
    local parseline="$1"
    local pattern="^[[:space:]]*%chk=(.+)$"
    if [[ $parseline =~ $pattern ]]; then
        checkpointfile=${BASH_REMATCH[1]}
    else 
        return 1
    fi
}



# Parse the commands that have been passed to Gaussian09
parseInputfile ()
{
    # The route section contains one or more lines.
    # It always starts with # folowed by a space or the various verbosity levels 
    # NPT (case insensitive). The route section is terminated by a blank line.
    # It is immediately followed by the title section, which can also consist of 
    # multiple lines made up of (almost) anything. It is also terminated by a blank line.
    # (Extracting the title is not necessary for writing the input file,
    # but we can do it anyway as it may become handy later.)
    local line appendline pattern
    local storeRoute=0 storeTitle=0 addline=0
    while read -r line; do
        getCheckpointfile "$line" && continue
        pattern="^[[:space:]]*#[nNpPtT]?[[:space:]]"
        if [[ $line =~ $pattern || "$addline" == "1" ]]; then
            if [[ $line =~ ^[!]+ ]]; then
                continue
            elif [[ $line =~ ^[[:space:]]*$ && $storeRoute == 1 ]]; then
                storeRoute=0
                storeTitle=1
                routeSection="$appendline"
                unset appendline
                continue
            elif [[ $line =~ ^[[:space:]]*$ && $storeTitle == 1 ]]; then
                storeTitle=0 addline=0
                titleSection="$appendline"
                break
            else
                appendline="$appendline $line"
                [[ -z $routeSection ]] && storeRoute=1
                addline=1
            fi
        fi
    done < "$1"
}

removeOptKeyword ()
{
    local testRouteSection="$1"
    local pattern
    pattern="([oO][pP][tT][^[:space:]]*)([[:space:]]|$)"
    if [[ $testRouteSection =~ $pattern ]]; then
      local optKeywordOptions="${BASH_REMATCH[1]}"
      message "Found '$optKeywordOptions' in the route section."
      newRouteSection=${testRouteSection/$optKeywordOptions/}
      return 1
    fi
}

removeFreqKeyword ()
{
    local testRouteSection="$1"
    local pattern
    pattern="([Ff][Rr][Ee][Qq][^[:space:]]*)([[:space:]]|$)"
    if [[ $testRouteSection =~ $pattern ]]; then
      local freqKeywordOptions="${BASH_REMATCH[1]}"
      message "Found '$freqKeywordOptions' in the route section."
      newRouteSection=${testRouteSection/$freqKeywordOptions/}
      return 1
    fi
}

removeGuessKeyword ()
{
    local testRouteSection="$1"
    local pattern
    pattern="([Gg][Uu][Ee][Ss][Ss][^[:space:]]*)([[:space:]]|$)"
    if [[ $testRouteSection =~ $pattern ]]; then
      local guessKeywordOptions="${BASH_REMATCH[1]}"
      message "Found '$guessKeywordOptions' in the route section."
      newRouteSection=${testRouteSection/$guessKeywordOptions/}
      return 1
    fi
}

removeGeomKeyword ()
{
    local testRouteSection="$1"
    local pattern
    pattern="([Gg][Ee][Oo][Mm][^[:space:]]*)([[:space:]]|$)"
    if [[ $testRouteSection =~ $pattern ]]; then
      local geomKeywordOptions="${BASH_REMATCH[1]}"
      message "Found '$geomKeywordOptions' in the route section."
      newRouteSection=${testRouteSection/$geomKeywordOptions/}
      return 1
    fi
}

removePopKeyword ()
{
    local testRouteSection="$1"
    local pattern
    pattern="([Pp][Oo][Pp][^[:space:]]*)([[:space:]]|$)"
    if [[ $testRouteSection =~ $pattern ]]; then
      local popKeywordOptions="${BASH_REMATCH[1]}"
      message "Found '$popKeywordOptions' in the route section."
      newRouteSection=${testRouteSection/$popKeywordOptions/}
      return 1
    fi
}

addRunKeywords ()
{ 
    local newKeywords="geom=allcheck guess(read,only) output=wfx"
    newRouteSection="$1 $newKeywords"
}

# Print the route section in human readable form
printNewRouteSection ()
{
    fold -w80 -c -s <<< "$newRouteSection"
}

printNewInputFile ()
{
    
    parseInputfile "$1"
    #  echo "$checkpointfile"
    #  echo "$routeSection"
    #  echo "$titleSection"
    
    newRouteSection="$routeSection"
    
    while ! removeOptKeyword   "$newRouteSection" ; do : ; done
    while ! removeFreqKeyword  "$newRouteSection" ; do : ; done
    while ! removeGuessKeyword "$newRouteSection" ; do : ; done
    while ! removeGeomKeyword  "$newRouteSection" ; do : ; done
    while ! removePopKeyword   "$newRouteSection" ; do : ; done
    
    addRunKeywords "$newRouteSection"
    
    if [[ -z $checkpointfile ]] ; then
      checkpointfile="${1%.*}.chk"
      # Check if exists
    fi
    
    echo "%chk=$checkpointfile"
    printNewRouteSection
    echo ""
    wavefunctionfile="${checkpointfile%.chk}.wfx"
    echo "$wavefunctionfile"
    echo
}

# Main

inputFilename="$1"
outputFilename="${inputFilename%.*}.prop.com"

printNewInputFile "$inputFilename" > "$outputFilename"

message "Modified '$titleSection'."
message "New Input is called '$outputFilename'."
# cat $outputFilename

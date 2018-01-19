#!/bin/bash

scriptname=${0##*\/} # Remove trailing path
scriptname=${scriptname%.sh} # remove scripting ending (if present)

version="0.1.5"
versiondate="2018-01-19"

# A script to take an input file and write a new inputfile to 
# obtain a wfx file.
# To Do: import (formatted) checkpoint files

#hlp This script takes a Gaussian inputfile and writes a new inputfile for a property run.
#hlp Version: $version ($versiondate)
#hlp Usage: $scriptname [options] filename

#
# Print logging information and warnings nicely.
# If there is an unrecoverable error: display a message and exit.
#

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

#
# Print some helping commands
# The lines are distributed throughout the script and grepped for
#

helpme ()
{
    # message "This script takes a Gaussian inputfile and writes a new inputfile for a property run."
    # message "There are no options yet. (Work in progress, I guess.)"
    # message "Version: $version ($versiondate)"
    local line
    local pattern="^[[:space:]]*#hlp[[:space:]](.*$)"
    while read -r line; do
      [[ $line =~ $pattern ]] && eval "echo \"${BASH_REMATCH[1]}\""
    done < <(grep "#hlp" "$0")
    exit 0
}

getCheckpointfile ()
{
    # The checkpointfile should be indicated in the original input file
    # (It is a link 0 command and should therefore before the route section.)
    local parseline="$1"
    local pattern="^[[:space:]]*%chk=([^[:space:]]+)([[:space:]]+|$)"
    if [[ $parseline =~ $pattern ]]; then
        checkpointfile="${BASH_REMATCH[1]}"
    else 
        return 1
    fi
}

removeComment ()
{
    local variableName="$1" variableContent="$2"
    local pattern="^[[:space:]]*([^!]+)[!]*[[:space:]]*(.*)$"
    if [[ $variableContent =~ $pattern ]] ; then
      printf -v "$variableName" "%s" "${BASH_REMATCH[1]}"
      [[ ! -z ${BASH_REMATCH[2]} ]] && message "Removed comment: ${BASH_REMATCH[2]}"
    else
      return 1 # Return false if blank line
    fi
}

parseInputfile ()
{
    # The route section contains one or more lines.
    # It always starts with # folowed by a space or the various verbosity levels 
    # NPT (case insensitive). The route section is terminated by a blank line.
    # It is immediately followed by the title section, which can also consist of 
    # multiple lines made up of (almost) anything. It is also terminated by a blank line.
    # Following that is the charge and multiplicity.
    # (Extracting the title, charge and multiplicity is not necessary for writing 
    # the input file for wfx extraction, so it is skipped here.
    # It may be necessary in other instances, see g09.propnbo6.)
    local line appendline 
    # The hash marks the beginning of the route
    local routeStartPattern="^[[:space:]]*#[nNpPtT]?[[:space:]]"
    local storeRoute=0 
    while read -r line; do
      # If we found the checkpointfile, we can skip out of the loop
      if [[ -z $checkpointfile ]] ; then
        getCheckpointfile "$line" && continue
      fi
      if (( storeRoute == 0 )) ; then
        if [[ $line =~ $routeStartPattern ]] ; then
          storeRoute=1
          removeComment appendline "$line"
          routeSection="$appendline"
          continue
        fi
      fi
      if (( storeRoute == 1 )) ; then
        if [[ $line =~ ^[[:space:]]*$ ]]; then
          storeRoute=2
          break
        fi
        removeComment appendline "$line"
        routeSection="$routeSection $appendline"
      fi
    done < "$1"
}

collateKeywords ()
{
    # This function removes spaces which have been entered in the original input
    # so that the folding (to 80 characters) doesn't break a keyword.
    local inputstring="$1"
    # The collated section will be saved to
    local keepstring
    # If we encounter a long keyword stack, we need to set a different returncode
    local returncode=0
    # extract the hashtag of the route section
    local routeStartPattern="^[[:space:]]*(#[nNpPtT]?)[[:space:]]"
    if [[ $inputstring =~ $routeStartPattern ]] ; then
      keepstring="${BASH_REMATCH[1]}"
      inputstring="${inputstring//${BASH_REMATCH[0]}/}"
    fi

    # The following formats for the input of keywords are given in the manual:
    #   keyword = option
    #   keyword(option)
    #   keyword=(option1, option2, …)
    #   keyword(option1, option2, …)
    # Spaces can be added or left out, I could also confirm that the following will work, too:
    #   keyword (option[1, option2, …])
    #   keyword = (option[1, option2, …])
    # Spaces, tabs, commas, or forward slashes can be used in any combination 
    # to separate items within a line. 
    # Multiple spaces are treated as a single delimiter.
    # see http://gaussian.com/input/?tabid=1
    # The ouptput of this function should only use the keywords without any options, or
    # the following format: keyword=(option1,option2,…) [no spaces]
    local keywordpattern="[^[:space:],/=]+"
    local keywordoptions="[[:space:]]*=[[:space:]]*[^[:space:],/\(\)]+|[[:space:]]*[=]?[[:space:]]*\([^\)]+\)"
    local keywordterminate="[[:space:],/]+|$"
    local testpattern="($keywordpattern)($keywordoptions)?($keywordterminate)"
    local keepKeyword keepOptions
    while [[ $inputstring =~ $testpattern ]] ; do
      # Unify input pattern and remove unnecessary spaces
      inputstring="${inputstring//${BASH_REMATCH[0]}/}"
      keepKeyword="${BASH_REMATCH[1]}"
      keepOptions="${BASH_REMATCH[2]}"
      keepTerminate="${BASH_REMATCH[3]}"
      if [[ $keepOptions =~ ^[[:space:]]*[=]?[[:space:]]*[\(]?([^\)]+)[\)]?[[:space:]]*$ ]] ; then
        keepOptions="${BASH_REMATCH[1]}"
        keepKeyword="$keepKeyword(${keepOptions// /})"
      fi
      if [[ $keepTerminate =~ / ]] ; then
        keepKeyword="$keepKeyword/"
      fi
      (( ${#keepKeyword} > 80 )) && returncode=1
      if [[ $keepstring =~ /$ ]] ; then
        keepstring="$keepstring$keepKeyword"
      else
        keepstring="$keepstring $keepKeyword"
      fi
    done

    echo "$keepstring"
    return $returncode
}

removeAnyKeyword ()
{
    # Takes in a string (the route section) and 
    local testLine="$1"
    # removes the pattern (keyword) if present and 
    local testPattern="$2"
    # stores the result to the new route section.
    # Since spaces have been removed form within the keywords previously with collateKeywords, 
    # and inter-keyword delimiters are set to spaces only also, 
    # it is safe to use that as a criterion to remove unnecessary keywords.
    # The test pattern is extended to catch the whole keyword including options.
    local extendedPattern="($testPattern[^[:space:]]*)([[:space:]]+|$)"
    if [[ $testLine =~ $extendedPattern ]] ; then
      local foundPattern=${BASH_REMATCH[1]}
      message "Removed keyword '$foundPattern'."
      newRouteSection="${testLine/$foundPattern/}"
      return 1
    fi
}

removeOptKeyword ()
{
    # Assigns the opt keyword to the pattern
    local testRouteSection="$1"
    local pattern
    pattern="[Oo][Pp][Tt]"
    removeAnyKeyword "$testRouteSection" "$pattern" || return 1
}

removeFreqKeyword ()
{
    # Assign the freq keyword to the pattern
    local testRouteSection="$1"
    local pattern
    pattern="[Ff][Rr][Ee][Qq]"
    removeAnyKeyword "$testRouteSection" "$pattern" || return 1
}

removeGuessKeyword ()
{
    # Assigns the guess heyword to the pattern
    local testRouteSection="$1"
    local pattern
    pattern="[Gg][Uu][Ee][Ss][Ss]"
    removeAnyKeyword "$testRouteSection" "$pattern" || return 1
}

removeGeomKeyword ()
{
    # Assigns the geom keyword to the pattern
    local testRouteSection="$1"
    local pattern
    pattern="[Gg][Ee][Oo][Mm]"
    removeAnyKeyword "$testRouteSection" "$pattern" || return 1
}

removePopKeyword ()
{
    local testRouteSection="$1"
    local pattern
    pattern="[Pp][Oo][Pp]"
    removeAnyKeyword "$testRouteSection" "$pattern" || return 1
}

removeOutputKeyword ()
{
    local testRouteSection="$1"
    local pattern
    local functionExitStatus=0
    pattern="[Oo][Uu][Tt][Pp][Uu][Tt]"
    removeAnyKeyword "$testRouteSection" "$pattern" || functionExitStatus=1
    if (( functionExitStatus != 0 )) ; then
      warning "Presence of the 'OUTPUT' keyword might indicate that the calculation is not suited for a property run."
    fi
    return $functionExitStatus
}

addRunKeywords ()
{ 
    local newKeywords="geom(allcheck) guess(read,only) output=$wavefunctionType"
    newRouteSection="$1 $newKeywords"
}
    
createNewInputFileData ()
{
    parseInputfile "$1"

    # If there were any long keywords, then return value is not 0.
    # A warning must be issued
    newRouteSection=$(collateKeywords "$routeSection" || return 1)
    (( $? > 0 )) && warning "Found extremely long keyword. Check generated input before submitting the calculation."
    
    while ! removeOptKeyword    "$newRouteSection" ; do : ; done
    while ! removeFreqKeyword   "$newRouteSection" ; do : ; done
    while ! removeGuessKeyword  "$newRouteSection" ; do : ; done
    while ! removeGeomKeyword   "$newRouteSection" ; do : ; done
    while ! removePopKeyword    "$newRouteSection" ; do : ; done
    while ! removeOutputKeyword "$newRouteSection" ; do : ; done

    addRunKeywords "$newRouteSection"
    
    # If the checkpoint file was not specified in the input file, guess it
    if [[ -z $checkpointfile ]] ; then
      checkpointfile="${1%.*}.chk"
      # Check if the guessed checkpointfile exists
      # (We'll trust the user if it was specified in the input file,
      #  after all the calculation might not be completed yet.)
      [[ ! -e $checkpointfile ]] && fatal "Cannot find '$checkpointfile'."
    fi
    wavefunctionfile="${checkpointfile%.chk}.$wavefunctionType"
    # Check if wavefunctionfile already exists
    [[ -e $wavefunctionfile ]] && fatal "File '$wavefunctionfile' already exists. Rename or delete it."
}   

# Print the input file in a more readable form
printNewInputFile ()
{
    echo "%oldchk=$checkpointfile"
    echo "%NoSave"
    fold -w80 -c -s <<< "$newRouteSection"
    echo ""
    echo "$wavefunctionfile"
    echo ""
}

#
# Main
#

(( $# == 0 )) && helpme
#hlp OPTIONS:
#hlp   -h     Prints this message
[[ "$1" == "-h" ]] && helpme

#hlp   -n     Produces wfn instead of wfx file
if [[ "$1" == "-n" ]] ; then
  wavefunctionType="wfn"
  shift
else
  wavefunctionType="wfx"
fi


inputFilename="$1"
[[ ! -e "$inputFilename" ]] && fatal "Cannot access '$inputFilename'."
[[ ! -r "$inputFilename" ]] && fatal "Cannot access '$inputFilename'."

outputFilename="${inputFilename%.*}.prop.com"
[[   -e "$outputFilename" ]] && fatal "File '$outputFilename' exists. Rename or delete it."

createNewInputFileData "$inputFilename"
printNewInputFile > "$outputFilename"

message "Modified '$inputFilename'."
message "New Input is called '$outputFilename'."
message "$scriptname is part of tools-for-g09.bash $version ($versiondate)"

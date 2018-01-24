#!/bin/bash
how_called="$0 $@"

scriptname=${0##*\/} # Remove trailing path
scriptname=${scriptname%.sh} # remove scripting ending (if present)

version="0.1.8"
versiondate="2018-01-24"

# A script to take an input file and write a new inputfile to 
# perform a frequency calculation.
# To Do: import (formatted) checkpoint files

#hlp This script takes a Gaussian inputfile and writes a new inputfile for a frequency run.
#hlp The newly created inputfile relies on a checkpointfile to read all data.

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
    echo "WARNING: " "$@" >&2
    return 1
}

fatal ()
{
    echo "ERROR  : " "$@" >&2
    exit 1
}

#
# Print some helping commands
# The lines are distributed throughout the script and grepped for
#

helpme ()
{
    local line
    local pattern="^[[:space:]]*#hlp[[:space:]]?(.*)$"
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
    local line appendline 
    # The hash marks the beginning of the route
    local routeStartPattern="^[[:space:]]*#[nNpPtT]?[[:space:]]"
    local storeRoute=0 storeTitle=0 storeChargeMultiplicity=0 
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
          storeTitle=1
          storeRoute=2
          continue
        fi
        removeComment appendline "$line" 
        [[ ! -z $appendline ]] && routeSection="$routeSection $appendline"
        unset appendline
        continue
      fi
      if (( storeTitle == 1 )) ; then
        if [[ $line =~ ^[[:space:]]*$ ]]; then
          storeTitle=2
          storeChargeMultiplicity=1
          continue
        fi
        removeComment appendline "$line" 
        [[ ! -z $appendline ]] && titleSection="$titleSection $appendline"
        unset appendline
        continue
      fi
      if (( storeChargeMultiplicity == 1 )) ; then
        removeComment appendline "$line" 
        pattern="^[[:space:]]*([0-9]+)[[:space:]]+([0-9]+)[[:space:]]*$"
        [[ $appendline =~ $pattern ]] 
        molCharge="${BASH_REMATCH[1]}"
        molMultiplicity="${BASH_REMATCH[2]}"
        # We now have everything we need
        break
      fi

    done < "$1"
}

collateKeywordOptions ()
{
    # The function takes an inputstring and removes any unnecessary spaces
    # needed for collateKeywords
    local inputstring="$1"
    # The collated section will be saved to
    local keepstring transformstring
    # Any combination of spaces, equals signs, and opening parentheses
    # can and need to be removed
    local removeFront="[[:space:]]*[=]?[[:space:]]*[\(]?"
    # Any trailing closing parentheses and spaces need to be cut
    local removeEnd="[\)]?[[:space:]]*"
    [[ $inputstring =~ $removeFront([^\)]+)$removeEnd ]] && inputstring="${BASH_REMATCH[1]}"
    
    # Spaces, tabs, or commas can be used in any combination
    # to separate items within the options.
    # Does massacre IOPs.
    local pattern="[^[:space:],]+([[:space:]]*=[[:space:]]*[^[:space:],]+)?([[:space:],]+|$)"
    while [[ $inputstring =~ $pattern ]] ; do
      transformstring="${BASH_REMATCH[0]}"
      inputstring="${inputstring//${BASH_REMATCH[0]}/}"
      # remove stuff
      transformstring="${transformstring// /}"
      transformstring="${transformstring//,/}"
      if [[ -z $keepstring ]] ; then
        keepstring="$transformstring"
      else
        keepstring="$keepstring,$transformstring"
      fi
    done
    echo "$keepstring"
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
    # Exeptions to the above: temperature=500 and pressure=2, 
    # where the equals is the only accepted form.
    # This is probably because they can also be options to 'freq'.
    local keywordPattern="[^[:space:],/\(=]+"
    local optionPatternEquals="[[:space:]]*=[[:space:]]*[^[:space:],/\(\)]+"
    local optionPatternParens="[[:space:]]*[=]?[[:space:]]*\([^\)]+\)"
    local keywordOptions="$optionPatternEquals|$optionPatternParens"
    local keywordTerminate="[[:space:],/]+|$"
    local testPattern="($keywordPattern)($keywordOptions)?($keywordTerminate)"
    local keepKeyword keepOptions
    local numericalPattern="[[:digit:]]+\.?[[:digit:]]*"
    while [[ $inputstring =~ $testPattern ]] ; do
      # Unify input pattern and remove unnecessary spaces
      # Remove found portion from inputstring:
      inputstring="${inputstring//${BASH_REMATCH[0]}/}"
      # Keep keword, options, and how it was terminated
      keepKeyword="${BASH_REMATCH[1]}"
      keepOptions="${BASH_REMATCH[2]}"
      keepTerminate="${BASH_REMATCH[3]}"

      # Remove spaces from IOPs (only evil people use them there)
      if [[ $keepKeyword =~ ^[Ii][Oo][Pp]$ ]] ; then
        keepKeyword="$keepKeyword$keepOptions"
        keepKeyword="${keepKeyword// /}"
        unset keepOptions # unset to not run into next 'if'
      fi

      if [[ ! -z $keepOptions ]] ; then 
        # remove spaces, equals, parens from front and end
        # substitute option separating spaces with commas
        keepOptions=$(collateKeywordOptions "$keepOptions")

        # Check for the exceptions to the desired format
        if [[ $keepKeyword =~ ^[Tt][Ee][Mm][Pp].*$ ]] ; then
          if [[ ! $keepOptions =~ ^$numericalPattern$ ]] ; then
            warning "Unrecognised format for temperature: $keepOptions."
            returncode=1
          fi
          keepKeyword="$keepKeyword=$keepOptions"
        elif [[ $keepKeyword =~ ^[Pp][Rr][Ee].*$ ]] ; then
          if [[ ! $keepOptions =~ ^$numericalPattern$ ]] ; then
            warning "Unrecognised format for temperature: $keepOptions."
            returncode=1
          fi
          keepKeyword="$keepKeyword=$keepOptions"
        else
          keepKeyword="$keepKeyword($keepOptions)"
        fi
      fi
      if [[ $keepTerminate =~ / ]] ; then
        keepKeyword="$keepKeyword/"
      fi
      if (( ${#keepKeyword} > 80 )) ; then
        returncode=1
        warning "Found extremely long keyword, heck input before running the calculation."
      fi
      if [[ $keepstring =~ /$ ]] ; then
        keepstring="$keepstring$keepKeyword"
      elif [[ -z $keepstring ]] ; then
        keepstring="$keepKeyword"
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
      #echo "-->|${BASH_REMATCH[0]}|<--" #(Debug Pattern:)
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
    local functionExitStatus=0
    local pattern
    pattern="[Ff][Rr][Ee][Qq]"
    removeAnyKeyword "$testRouteSection" "$pattern" || functionExitStatus=1
    if (( functionExitStatus != 0 )) && [[ $rerunFreqAnalysis == "false" ]] ; then
      warning "It appears that you want to run a frequency calculation based on a frequency calculation."
    fi
    return $functionExitStatus
}

removeTempKeyword ()
{
    # Assign the temp keyword to the pattern
    local testRouteSection="$1"
    local functionExitStatus=0
    local pattern
    pattern="[Tt][Ee][Mm][Pp]"
    removeAnyKeyword "$testRouteSection" "$pattern" || functionExitStatus=1
    if (( functionExitStatus != 0 )) ; then
      message "Avoiding double specification."
    fi
    return $functionExitStatus
}

removePresKeyword ()
{
    # Assign the temp keyword to the pattern
    local testRouteSection="$1"
    local functionExitStatus=0
    local pattern
    pattern="[Pp][Rr][Ee]"
    removeAnyKeyword "$testRouteSection" "$pattern" || functionExitStatus=1
    if (( functionExitStatus != 0 )) ; then
      message "Avoiding double specification."
    fi
    return $functionExitStatus
}

removeGuessKeyword ()
{
    # Assigns the guess keyword to the pattern
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
    local functionExitStatus=0
    local pattern
    pattern="[Pp][Oo][Pp]"
    removeAnyKeyword "$testRouteSection" "$pattern" || functionExitStatus=1
    if (( functionExitStatus != 0 )) ; then
      message "It is safer to perform a population analysis with a property run."
    fi
    return $functionExitStatus
}

removeOutputKeyword ()
{
    local testRouteSection="$1"
    local functionExitStatus=0
    local pattern
    pattern="[Oo][Uu][Tt][Pp][Uu][Tt]"
    removeAnyKeyword "$testRouteSection" "$pattern" || functionExitStatus=1
    if (( functionExitStatus != 0 )) ; then
      warning "Presence opt the 'OUTPUT' keyword might indicate that the calculation is not suited for a frequency calculation."
    fi
    return $functionExitStatus
}

testAndFormatTempKeyword ()
{
    local numericalPattern="[[:digit:]]+\.?[[:digit:]]*"
    if [[ $1 =~ ^$numericalPattern$ ]] ; then
      echo "Temperature=$1"
    else
      fatal "The value '$1' for the temperature is not numerical."
    fi
}

testAndFormatPresKeyword ()
{
    local numericalPattern="[[:digit:]]+\.?[[:digit:]]*"
    if [[ $1 =~ ^$numericalPattern$ ]] ; then
      echo "Pressure=$1"
    else
      fatal "The value '$1' for the pressure is not numerical."
    fi
}

addRunKeywords ()
{ 
    local newKeywords
    newKeywords="geom(check) guess(read)"
    newKeywords="$newKeywords $addFrequencyKeyword $addTempKeyword $addPresKeyword $customRouteInput"
    newKeywords=$(collateKeywords "$newKeywords")
    echo "$newKeywords"
}
    
createNewInputFileData ()
{
    parseInputfile "$1"

    # If there were any long keywords, then return value is not 0.
    # A warning must be issued
    newRouteSection=$(collateKeywords "$routeSection")
    
    while ! removeOptKeyword    "$newRouteSection" ; do : ; done
    while ! removeFreqKeyword   "$newRouteSection" ; do : ; done
    while ! removeTempKeyword   "$newRouteSection" ; do : ; done
    while ! removePresKeyword   "$newRouteSection" ; do : ; done
    while ! removeGuessKeyword  "$newRouteSection" ; do : ; done
    while ! removeGeomKeyword   "$newRouteSection" ; do : ; done
    while ! removePopKeyword    "$newRouteSection" ; do : ; done
    while ! removeOutputKeyword "$newRouteSection" ; do : ; done

    newRouteSection="$newRouteSection $(addRunKeywords)"
    
    # If the checkpoint file was not specified in the input file, guess it
    if [[ -z $checkpointfile ]] ; then
      checkpointfile="${1%.*}.chk"
      # Check if the guessed checkpointfile exists
      # (We'll trust the user if it was specified in the input file,
      #  after all the calculation might not be completed yet.)
      [[ ! -e $checkpointfile ]] && fatal "Cannot find '$checkpointfile'."
    fi
    # Check if new checkpointfile already exists
    if [[ $rerunFreqAnalysis == "true" ]] ; then 
      newCheckpointfile=${checkpointfile%.chk}.$rerunSuffix.chk
    else
      newCheckpointfile=${checkpointfile%.chk}.$calcSuffix.chk
    fi
    [[ -e $newCheckpointfile ]] && fatal "File '$newCheckpointfile' already exists. Rename or delete it."
}   

# Print the input file in a more readable form
printNewInputFile ()
{
    echo "%oldchk=$checkpointfile"
    echo "%chk=$newCheckpointfile"
    [[ $rerunFreqAnalysis == "true" ]] && echo "%NoSave"
    fold -w80 -c -s <<< "$newRouteSection"
    echo ""
    fold -w80 -c -s <<< "$titleSection"
    echo ""
    echo "$molCharge   $molMultiplicity"
    echo ""
    if [[ ! -z $customTail ]] ; then
      echo "$customTail"
      echo ""
    fi
    echo "! Input file created with: "
    echo "!   $how_called"
}

#
# Main
#

(( $# == 0 )) && helpme

rerunFreqAnalysis="false"
declare calcSuffix rerunSuffix

# Evaluate options 
#
#hlp Usage: $scriptname [options] filename
#hlp
#hlp Options:
while getopts :o:RT:P:r:t:hu options ; do
    case $options in

           #hlp   -o <ARG>   Adds options <ARG> to the frequency keyword.
           #hlp              May be specified multiple times.
           #hlp              The stack will be collated, but no sanity check will be performed.
           #hlp              Example Options: NoRaman, VCD, ReadFC
           #hlp
        o) if [[ -z $addFrequencyOptions ]] ; then
             addFrequencyOptions="$OPTARG"
           else
             addFrequencyOptions="$addFrequencyOptions, $OPTARG" 
           fi
           ;;

           #hlp   -R         Writes a property run input file to redo a frequency calculation.
           #hlp              Adds option 'ReadFC' to the frequency option list.
           #hlp              Should be specified with a temperature or pressure
           #hlp              via the '-T <ARG>' or '-P <ARG>' switches.
           #hlp              No check is performed whether the supplied input file is a
           #hlp              frequency calculation.
           #hlp
        R) rerunFreqAnalysis="true" 
           if [[ -z $addFrequencyOptions ]] ; then
             addFrequencyOptions="ReadFC"
           else
             addFrequencyOptions="ReadFC, $addFrequencyOptions"
           fi
           warning "If not based on a frequency calculation, this will produce an error."
           ;;

           #hlp   -T <ARG>   Specify temperature in kelvin.
           #hlp              Writes 'Temperature=<ARG>' to the route section. 
           #hlp              If specified multiple times, only the last one has an effect.
           #hlp              It will, however, mess with the filename.
           #hlp 
        T) addTempKeyword=$(testAndFormatTempKeyword "$OPTARG") || exit $?
           calcSuffix="T${OPTARG//\./-}${calcSuffix}"
           ;;

           #hlp   -P <ARG>   Specify pressure in atmosphere.
           #hlp              Writes 'Pressure=<ARG>' to the route section. 
           #hlp              If specified multiple times, only the last one has an effect.
           #hlp              It will, however, mess with the filename.
           #hlp 
        P) addPresKeyword=$(testAndFormatPresKeyword "$OPTARG") || exit $?
           calcSuffix="${calcSuffix}P${OPTARG//\./-}"
           ;;

           #hlp   -r <ARG>   Adds custom command <ARG> to the route section.
           #hlp              May be specified multiple times.
           #hlp              The stack will be collated, but no sanity check will be performed.
           #hlp 
        r) customRouteInput="$customRouteInput $OPTARG" ;;

           #hlp   -t <ARG>   Adds <ARG> to the end (tail) of the new input file.
           #hlp              If specified multiple times, only the last one has an effect.
           #hlp 
        t) customTail="$OPTARG" ;;

           #hlp   -h         Prints this help message.
           #hlp 
        h) helpme ;;
        u) helpme ;;

       \?) warning "Invalid option: -$OPTARG." ;;

        :) fatal "Option -$OPTARG requires an argument." ;;
    esac
done
shift $((OPTIND-1))

if [[ $rerunFreqAnalysis == "true" ]] ; then
  rerunSuffix="rep$calcSuffix"
else
  calcSuffix="freq.$calcSuffix"
fi

[[ -z $1 ]] && fatal "No filename specified."
inputFilename="$1"
[[ ! -e "$inputFilename" ]] && fatal "Cannot access '$inputFilename'."
[[ ! -r "$inputFilename" ]] && fatal "Cannot access '$inputFilename'."

shift
(( $# > 0 )) && warning "Additional input ($@) will be ignored."

if [[ $rerunFreqAnalysis == "true" ]] ; then 
  outputFilename="${inputFilename%.freq.*}.freq.$rerunSuffix.com"
else
  outputFilename="${inputFilename%.*}.$calcSuffix.com"
fi
[[   -e "$outputFilename" ]] && fatal "File '$outputFilename' exists. Rename or delete it."

if [[ -z $addFrequencyOptions ]] ; then
  addFrequencyKeyword="freq"
else
  addFrequencyKeyword="freq($addFrequencyOptions)"
fi

createNewInputFileData "$inputFilename"
printNewInputFile > "$outputFilename"

message "Modified '$inputFilename'."
message "New input is called '$outputFilename'."
#hlp (Martin; $version; $versiondate.)
message "$scriptname is part of tools-for-g09.bash $version ($versiondate)"

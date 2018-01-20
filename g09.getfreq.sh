#!/bin/bash
#hlp This tool creates a summary for a single (or more) frequency calculation(s)
#hlp of the quantum chemical software suite Gaussian09.
#hlp It will, however, not fail if it is not one. 
#hlp It looks for a defined set of keywords and writes them to the screen.

# See also http://codereview.stackexchange.com/q/131666/92423
# 
# This was last updated with 
version="0.1.5"
versiondate="2018-01-20"
# of tools-for-g09.bash

scriptname=${0##*\/} # Remove trailing path
scriptname=${scriptname%.sh} # remove scripting ending (if present)

# Intitialise scriptoptions
errCount=0
printlevel=0
isOptimisation=0
isFreqCalc=0
ignorePrintlevelSwitch=0

# Initialise all variables that are of interest
declare filename functional temperature pressure 
declare electronicEnergy zeroPointEnergy thermalCorrEnergy thermalCorrEnthalpy thermalCorrGibbs
declare -a contributionNames thermalE heatCapacity entropy
declare routeSection

# Errors, Info and Warnings
fatal ()
{
    echo "ERROR  : " "$@"
    exit 1
}

message ()
{
    echo "INFO   : " "$@"
}

warning ()
{
    echo "WARNING: " "$@"
} 

#
# Print some helping commands
# The lines are distributed throughout the script and grepped for
#

helpme ()
{
    local line
    local pattern="^[[:space:]]*#hlp[[:space:]]?(.*)?$"
    while read -r line; do
      [[ "$line" =~ $pattern ]] && eval "echo \"${BASH_REMATCH[1]}\""
    done < <(grep "#hlp" "$0")
    exit 0
}

# Usage and help
usage ()
{
    message "Usage: $0 [options] filenames(s)"
    message "Options may be -v -V{0,1,2,3} -c"
    message "Use -h to display a longer help message."
    exit 0
}

# Parse the commands that have been passed to Gaussian09
getRouteSec ()
{
    # The route section is echoed in the log file, but it might spread over various lines
    # options might be cut off in the middle. It always starts with # folowed by a space
    # or the various verbosity levels NPT (case insensitive). The route section is 
    # terminated by a line of dahes. The script will stop reading the file if encountered.
    local line appendline 
    local addline=0
    while read -r line; do
        local pattern="^[[:space:]]*#[nNpPtT]?[[:space:]]"
        if [[ $line =~ $pattern || "$addline" == "1" ]]; then
            [[ $line =~ ^[[:space:]]*[-]+[[:space:]]*$ ]] && break
            appendline="$appendline$line"
            addline=1
        fi
    done < "$1" 

    routeSection="$appendline"
}

# Test the route section if it is an optimisation or frequency calculation (or both)
testRouteSec ()
{
    local testRouteSection="$1"
    local patternOpt="([oO][pP][tT][^[:space:]]*)([[:space:]]|$)"
    if [[ $testRouteSection =~ $patternOpt ]]; then
        warning "This appears to be an optimisation."
        warning "Found '${BASH_REMATCH[1]}' in the route section."
        warning "The script is not intended for creating a summary of an optimisation."
        isOptimisation=1
    fi
    local patternFreq="([Ff][Rr][Ee][Qq][^[:space:]]*)([[:space:]]|$)"
    if [[ $testRouteSection =~ $patternFreq ]]; then
        message "Found '${BASH_REMATCH[1]}' in the route section."
        isFreqCalc=1
    fi
}

# Print the route section in human readable form
printRouteSec ()
{
    message "Found route section:"
    fold -w80 -c -s <<< "$routeSection"
    echo "----"
}

getElecEnergy ()
{
    # The last value is the only of concern. Since the script is intended for single
    # point calculations, it is expected that the energy is printed early in the file.
    # It will not fail if it is an optimisation (warning printed earlier).
    local -r readWholeLine=$(grep -e 'SCF Done' "$1" | tail -n 1)
    # Gaussian output has following format, trap important information:
    # Method, electronic Energy
    # Example taken from BP86/cc-pVTZ for water (H2O): 
    #  SCF Done:  E(RB-P86) =  -76.4006006969     A.U. after   10 cycles
    local pattern="E\((.+)\) =[[:space:]]+([-]?[0-9]+\.[0-9]+)[[:space:]]+A\.U\..+ cycles"
    if [[ $readWholeLine =~ $pattern ]]; then
        functional="${BASH_REMATCH[1]}"
        electronicEnergy="${BASH_REMATCH[2]}"
    else
        return 1
    fi
}

# Get the desired information from the thermochemistry block
# parse the lines according to keywords and trap the values.

findTempPress ()
{
    local readWholeLine="$1"
    local pattern
    pattern="^Temperature[[:space:]]+ ([0-9]+\.[0-9]+)[[:space:]]+Kelvin\.[[:space:]]+Pressure[[:space:]]+ ([0-9]+\.[0-9]+)[[:space:]]+Atm\.$"
    if [[ $readWholeLine =~ $pattern ]]; then
        temperature="${BASH_REMATCH[1]}"
        pressure="${BASH_REMATCH[2]}"
    else
        return 1
    fi
}

findZeroPointEnergy ()
{
    local readWholeLine="$1"
    local pattern
    pattern="Zero-point correction=[[:space:]]+([-]?[0-9]+\.[0-9]+)"
    if [[ $readWholeLine =~ $pattern ]]; then
        zeroPointEnergy="${BASH_REMATCH[1]}"
    else
        return 1
    fi
}

findThermalCorrEnergy ()
{
    local readWholeLine="$1"
    local pattern
    pattern="Thermal correction to Energy=[[:space:]]+([-]?[0-9]+\.[0-9]+)"
    if [[ $readWholeLine =~ $pattern ]]; then
        thermalCorrEnergy="${BASH_REMATCH[1]}"
    else
        return 1
    fi
}

findThermalCorrEnthalpy ()
{
    local readWholeLine="$1"
    local pattern
    pattern="Thermal correction to Enthalpy=[[:space:]]+([-]?[0-9]+\.[0-9]+)"
    if [[ $readWholeLine =~ $pattern ]]; then
        thermalCorrEnthalpy="${BASH_REMATCH[1]}"
    else
        return 1
    fi
}

findThermalCorrGibbs ()
{
    local readWholeLine="$1"
    local pattern
    pattern="Thermal correction to Gibbs Free Energy=[[:space:]]+([-]?[0-9]+\.[0-9]+)"
    if [[ $readWholeLine =~ $pattern ]]; then
        thermalCorrGibbs="${BASH_REMATCH[1]}"
    else
        return 1
    fi
}

# In the entropy block the given table needs to be transposed.
# Heat capacity and the break up of the internal energy are usually not that important,
# but they come as a freebie.
getEntropy ()
{
     local index=0 line
     local pattern numpattern
     while read -r line; do
         pattern="^[[:space:]]*E[[:space:]]{1}\(Thermal\)[[:space:]]+CV[[:space:]]+S[[:space:]]*$"
         if [[ "$line" =~ $pattern ]]; then
             continue
         fi
         pattern="^[[:space:]]*KCal/Mol[[:space:]]+Cal/Mol-Kelvin[[:space:]]+Cal/Mol-Kelvin[[:space:]]*$"
         if [[ "$line" =~ $pattern ]]; then
             continue
         fi
         numpattern="[-]?[0-9]+\.[0-9]+"
         pattern="^[[:space:]]*([a-zA-Z]+)[[:space:]]+($numpattern)[[:space:]]+($numpattern)[[:space:]]+($numpattern)[[:space:]]*+$"
         if [[ "$line" =~ $pattern ]]; then
             contributionNames[$index]=${BASH_REMATCH[1]:0:3}
             thermalE[$index]=${BASH_REMATCH[2]}
             heatCapacity[$index]=${BASH_REMATCH[3]}
             entropy[$index]=${BASH_REMATCH[4]}
             (( index++ ))
         fi
     done < <(grep -A6 -e 'E (Thermal)[[:space:]]\+CV[[:space:]]\+S' "$1")
}

# If requested print the transposed table of entropies, heat capacities and the break up of the int. energy.
printEntropy ()
{
     local name
     printf "%-15s : " "Contrib."
     for name in "${contributionNames[@]}"; do
         printf "%-10s " "$name"
     done 
     printf "%-15s\n" "Unit"
     printf "%-11s %4s: " "thermal en." "(U)"
     for name in "${thermalE[@]}"; do
         printf "%+10.3f " "$name"
     done 
     printf "%-15s\n" "kcal/mol"
     printf "%-11s %4s: " "heat cap." "(Cv)"
     for name in "${heatCapacity[@]}"; do
         printf "%+10.3f " "$name"
     done 
     printf "%-15s\n" "cal/(mol K)"
     printf "%-11s %4s: " "entropy" "(S)"
     for name in "${entropy[@]}"; do
         printf "%+10.3f " "$name"
     done 
     printf "%-15s\n" "cal/(mol K)"

}

# Grep should be faster than parsing every line of the outputfile with =~
getThermochemistryLines ()
{
    grep -e 'Temperature.*Pressure' -e 'Zero-point correction' \
         -e 'Thermal correction to Energy' -e 'Thermal correction to Enthalpy' \
         -e 'Thermal correction to Gibbs Free Energy' \
         "$1"
}

# Parse the thermochemistry output
getThermochemistry ()
{
    local line
    while read -r line; do
        findTempPress           "$line"  && continue
        findZeroPointEnergy     "$line"  && continue
        findThermalCorrEnergy   "$line"  && continue
        findThermalCorrEnthalpy "$line"  && continue
        findThermalCorrGibbs    "$line"  && continue
    done < <(getThermochemistryLines "$1")
}

getAllEnergies ()
{
    getElecEnergy "$1" || warning "Unable to find electronic energy."
    (( isFreqCalc == 1 )) && getThermochemistry "$1"
    (( isFreqCalc == 1 )) && getEntropy "$1"
}

# If only one line of output is requested for easier importing
printAllEnergiesInline ()
{
    [[ -z $functional ]] && functional="na"
    [[ -z $electronicEnergy ]] && electronicEnergy="na"
    local fs="$1"
    local index
    local header=("Method" "T (K)" "P (atm)" "E(SCF) (au/p)" \
                  "E(ZPE) (au/p)" "U(corr) (au/p)" "H(corr) (au/p)" "G(corr) (au/p)" \
                  "S (cal/[mol K])" "Cv (cal/[mol K])")
    local values=("$functional" "$temperature" "$pressure" "$electronicEnergy" \
                  "$zeroPointEnergy" "$thermalCorrEnergy" "$thermalCorrEnthalpy" "$thermalCorrGibbs"\
                  "${entropy[0]}" "${heatCapacity[0]}")
    local printHeader printValues

    for (( index=0; index < ${#header[@]}; index++ )); do
        if (( ${#values[$index]} < ${#header[$index]} )); then
            printf -v printHeader "%s%-*s%s" "$printHeader" ${#header[$index]} "${header[$index]}" "$fs"
            printf -v printValues "%s%*s%s"  "$printValues" ${#header[$index]} "${values[$index]}" "$fs"
        else                                                                  
            printf -v printHeader "%s%-*s%s" "$printHeader" ${#values[$index]} "${header[$index]}" "$fs"
            printf -v printValues "%s%*s%s"  "$printValues" ${#values[$index]} "${values[$index]}" "$fs"
        fi
    done

    message "File: $filename"
    echo "$printHeader"
    echo "$printValues"
}

# Print a table (e.g. for archiving)
printAllEnergiesTable ()
{
     [[ -z $functional ]] && functional="(not available)"
     printf "%-25s %8s: %-20s %-20s\n"    "calculation details"   ""        "$functional"          "$filename" 
     printf "%-25s %8s: %20.3f %-20s\n"   "temperature"           "(T)"     "$temperature"         "K"
     printf "%-25s %8s: %20.5f %-20s\n"   "pressure"              "(p)"     "$pressure"            "atm"
     if [[ -z $electronicEnergy ]]; then
         printf "%-25s %8s: %-20s %-20s\n" "electr. en."          "(E)"     "(not available)"      ""
     else
         printf "%-25s %8s: %+20.10f %-20s\n" "electr. en."       "(E)"     "$electronicEnergy"    "hartree"
     fi
     printf "%-25s %8s: %+20.6f %-20s\n"  "zero-point corr."      "(ZPE)"   "$zeroPointEnergy"     "hartree/particle"
     printf "%-25s %8s: %+20.6f %-20s\n"  "thermal corr."         "(U)"     "$thermalCorrEnergy"   "hartree/particle"
     printf "%-25s %8s: %+20.6f %-20s\n"  "ther. corr. enthalpy"  "(H)"     "$thermalCorrEnthalpy" "hartree/particle"
     printf "%-25s %8s: %+20.6f %-20s\n"  "ther. corr. Gibbs en." "(G)"     "$thermalCorrGibbs"    "hartree/particle"
     printf "%-25s %8s: %+20.3f %-20s\n"  "entropy (total)"       "(S tot)" "${entropy[0]}"        "cal/(mol K)"
     printf "%-25s %8s: %+20.3f %-20s\n"  "heat capacity (total)" "(Cv t)"  "${heatCapacity[0]}"   "cal/(mol K)"
}

printSummary ()
{ 
     case $printlevel in
         0) printAllEnergiesInline " ";;
         c) printAllEnergiesInline ", ";;
         1) printAllEnergiesTable ;;
         2) printRouteSec 
            printAllEnergiesTable ;;
         3) printRouteSec
            printAllEnergiesTable
            printf "%s\nDetails of the composition\n" "----"
            printEntropy ;;
         *) fatal "Unrecognised printlevel: $printlevel"
     esac

     # All variable should be unset in case another file is processed
     unset filename functional temperature pressure 
     unset electronicEnergy zeroPointEnergy thermalCorrEnergy thermalCorrEnthalpy thermalCorrGibbs
     unset contributionNames thermalE heatCapacity entropy
     unset routeSection
}

analyseLog ()
{
    getRouteSec "$1" 
    testRouteSec "$routeSection"
    getAllEnergies "$1"
    if [[ $isFreqCalc == "1" ]]; then
        printSummary
        unset isFreqCalc isOptimisation
    else
        (( isOptimisation == 1 )) && local append=" (last value)"
        (( printlevel > 1 )) && printRouteSec
        message "$filename"
        message "Electronic energy$append: $electronicEnergy hartree"
        unset isOptimisation electronicEnergy routeSection
    fi
}

# Start main script

# Evaluate options
while getopts :vcV:hu options ; do
  #hlp Usage  : $scriptname [options] filenames(s)
  #hlp 
  #hlp Options:
    case $options in
        #hlp   -v         incrementally increase verbosity 
        v) [[ $ignorePrintlevelSwitch == 1 ]] || ((printlevel++)) ;;

        #hlp   -V [ARG]   set level of verbosity directly, ARG may be
        #hlp                0: (default) display a single line of most important values
        #hlp                1: display a short table of most important values (equal to -v)
        #hlp                2: like 1, also repeats the route section (equal to -vv)
        #hlp                3: like 2, also includes the decomposition of the entropy, thermal
        #hlp                   energy and heat capacity into electronic, translational, 
        #hlp                   rotational, and vibrational contributions (equal to -vvv)
        #hlp                If this option is found, -v will be ignored.
        V) if [[ $OPTARG =~ ^[0-9]{1}$ ]]; then
               printlevel="$OPTARG" 
               ignorePrintlevelSwitch=1
           else
               fatal "Invalid argument: $OPTARG"
           fi ;;

        #hlp   -c         like -V0 but the values are comma separated
        c) printlevel="c" ;;

        #hlp   -u         display short usage message
        u) usage ;;

        #hlp   -h         display this help
        h) helpme ;;

       \?) warning "Invalid option: -$OPTARG." ;;
        
        :) fatal "Option -$OPTARG requires an argument." ;;
    esac
done
#hlp 
#hlp This script is part of the tools-for-g09 bundle.
#hlp   https://github.com/polyluxus/tools-for-g09.bash
#hlp 
#hlp See also http://codereview.stackexchange.com/q/131666/92423

shift $((OPTIND-1))

# Check if filename is specified
if [[ $# == 0 ]]; then 
    fatal "No output file specified. Nothing to do. Try $scriptname -h for more information."
fi

# If the used locale is not English, the formatting of floating numbers of the 
# printf commands will produce an error
if [[ ! "$LANG" == "en_US.utf8" ]]; then 
    warning "Formatting might not properly work for '$LANG'."
    warning "Setting locale for this script."
    set -x
        export LC_NUMERIC="en_US.utf8"
    set +x
fi

# Assume all other commandline arguments are filenames
while [[ ! -z "$1" ]]; do
    filename="$1"
    if [[ ! -e "$filename" ]]; then 
        warning "Specified logfile '$filename' does not exist. Continue."
        ((errCount++))
    else
        analyseLog "$filename"
    fi
    shift
    [[ ! -z "$1" && $printlevel -gt 0 ]] && echo "==== Next file ===="
done

# Issue an error if files have not been found.
if (( "$errCount" > 0 )); then
    fatal "There have been one or more errors reading the specified files."
fi

#hlp (Martin; $version; $versiondate.)
message "$scriptname is part of tools-for-g09.bash $version ($versiondate)"

#!/bin/bash

#hlp $scriptname finds energy statements from Gaussian 09 calculations,
#hlp or find energy statements from all G09 log files in working directory.
#hlp 
scriptname=${0##*\/} # Remove trailing path
scriptname=${scriptname%.sh} # remove scripting ending (if present)
 
# Related Review of original code:
# http://codereview.stackexchange.com/q/129854/92423
# Thanks to janos and 200_success
# 
# This was last updated with 
version="0.1.9"
versiondate="2018-02-15"
# of tools-for-g09.bash

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

findEnergy ()
{
    local logfile="$1"
    # Initiate variables necessary for parsing output
    local readWholeLine pattern functional energy cycles
    # Find match from the end of the file 
    # Ref: http://unix.stackexchange.com/q/112159/160000
    # This is the slowest part. 
    # If the calulation is a single point with a properties block it might 
    # perform slower than $(grep -m1 'SCF Done'c $logfile | tail -n 1).
    readWholeLine=$(tac $logfile | grep -m1 'SCF Done')
    # Gaussian output has following format, trap important information:
    # Method, Energy, Cycles
    # Example taken from BP86/cc-pVTZ for water (H2O): 
    #  SCF Done:  E(RB-P86) =  -76.4006006969     A.U. after   10 cycles
    pattern="(E\(.+\)) = (.+) [aA]\.[uU]\.[^0-9]+([0-9]+) cycles"
    if [[ $readWholeLine =~ $pattern ]]
    then 
        functional="${BASH_REMATCH[1]}"
        energy="${BASH_REMATCH[2]}"
        cycles="${BASH_REMATCH[3]}"

        # Print the line, format it for table like structure
        printf "%-25s %-15s = %20s ( %6s )\n" ${1%.*} $functional $energy $cycles
    else
        printf "%-25s No energy statement found.\n" "${1%.*}"
    fi
}

getOnly ()
{
    # run only for commandline arguments
    # works if logfiles are specified
    local logfile="${1/%.com/.log}"
    if [[ -e $logfile ]]; then
        findEnergy "$logfile"
    else
        printf "%-25s No log file found.\n" "${1%.*}"
    fi
}

getAll ()
{
    # run over all commandfiles
    # ToDo: specify file suffixes
    local commandOrLogfile
    printf "%-25s %s\n" "Summary for " "${PWD#\/*\/*\/}" 
    printf "%-25s %s\n\n" "Created " "$(date +"%Y/%m/%d %k:%M:%S")"
    # Print a header
    printf "%-25s %-15s   %20s ( %6s )\n" "Command file" "Functional" "Energy / Hartree" "cycles"
    for commandOrLogfile in *com; do
        getOnly "$commandOrLogfile"
    done
}

# Get options
# Initialise options
OPTIND="1"

while getopts :h options ; do
  #hlp Usage: $scriptname [options] <filenames>
  #hlp
  #hlp If no filenames are specified, the script looks for all '*.com'
  #hlp files and assumes there is a matching '*.log' file.
  #hlp
  #hlp Options:
  case $options in
    #hlp   -h        Prints this help text
    #hlp
    h) helpme ;; 

    #hlp More options in preparation.
   \?) fatal "Invalid option: -$OPTARG." ;;

    :) fatal "Option -$OPTARG requires an argument." ;;

  esac
done

shift $(( OPTIND - 1 ))

if [[ $# == 0 ]]; then
    getAll
else
    # Print a header if more than one file specified
    (( $# > 1 )) && printf "%-25s %-15s   %20s ( %6s )\n" "Command file" "Functional" "Energy / Hartree" "cycles"
    for commandfile in "$@"; do
      getOnly "$commandfile"
    done
fi

#hlp (Martin; $version; $versiondate.)
echo "$scriptname is part of tools-for-g09.bash $version ($versiondate)"

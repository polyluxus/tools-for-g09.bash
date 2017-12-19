#!/bin/bash

# Find energy statement from a Gaussian 09 calculation
# Find energy statement from all G09 log files in working directory
# Related Review of original code:
# http://codereview.stackexchange.com/q/129854/92423
# Thanks to janos and 200_success
# 
# This was last updated with 
version="0.1.2"
versiondate="2017-12-19"
# of tools-for-g09.bash

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
    local commandfile logfile
    printf "%-25s %s\n" "Summary for " "${PWD#\/*\/*\/}" 
    printf "%-25s %s\n\n" "Created " "$(date +"%Y/%m/%d %k:%M:%S")"
    # Print a header
    printf "%-25s %-15s   %20s ( %6s )\n" "Command file" "Functional" "Energy / Hartree" "cycles"
    for commandfile in *com; do
        getOnly "$commandfile"
    done
}

if [[ $# == 0 ]]; then
    getAll
else
    for commandfile in "$@"; do
        getOnly "$commandfile"
    done
fi


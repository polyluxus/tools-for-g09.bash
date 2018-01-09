#!/bin/bash
#
# A very quick script to transform a checkpointfile
# to a formatted checkpointfile and then to xyz 
# coordinates using Open Babel.
# 
# This was last updated with 
version="0.1.2"
versiondate="2017-12-19"
# of tools-for-g09.bash

#
# CONFIGURATION
#
# How should the formatted checkpoint file be created?
# This must be an executable command, if used in conjunction
# with other tools-for-g09, then the wrapper should be fine.
# Uncomment the following line:
#   bin_formchk='g09.wrapper.sh formchk'
# I created a soft link without the ending, so that 
    bin_formchk='g09.wrapper formchk'
# works, too.
# If you have a local istall installation, and don't want to 
# use the wrapper, then the following line should work well
#   bin_formchk="formchk -3" 
#(-3 for verson 3 fchk; that is the default in the wrapper)
# The hard coded path to the binary works also.
#   bin_formchk="/path/to/g09/formchk -3"
#
# This script requires an installation of Open Babel.
# (It's syntax is:
#    obabel [-i<in-type>] <in-file> [-o<out-type>] -O<out-file>
# If you have added it to your $PATH, then
    bin_babel="obabel"
# should be enough.
# Otherwise, provide the path to the binary
#   bin_babel='/path/to/openbabel/bin/obabel'
#
# END CONFIGURATION
#

#
# Print logging information and warnings nicely.
# If there is an unrecoverable error: display a message and exit.
#

message ()
{
    echo "INFO   : " "$*"
}

indent ()
{
    echo -n "INFO   : " "$*"
}

warning ()
{
    echo "WARNING: " "$*" >&2
}

fatal ()
{
    echo "ERROR  : " "$*" >&2
    exit 1
}

#
# Test, whether we can access the given file/directory
#

is_file ()
{
    [[ -f $1 ]]
}

is_readable ()
{
    [[ -r $1 ]]
}

is_readable_file_or_exit ()
{
    is_file "$1"     || fatal "Specified file '$1' is no file or does not exist."
    is_readable "$1" || fatal "Specified file '$1' is not readable."
}

#
# Check if file exists and prevent overwriting
#

backup_if_exists ()
{
    if [[ -e "$1" ]]; then
        local filecount=1
        while [[ -e "$1.$filecount" ]]; do
            ((filecount++))
        done
        warning "File '$1' exists, will make backup."
        indent "  "
        mv -v "$1" "$1.$filecount"
    fi
}

#
# MAIN SCRIPT
#

if [[ -z "$1" ]] ; then
  fatal "No checkpointfile specified."
fi

if [[ "$1" == "-h" ]] ; then
  message "Usage: $0 <checkpointfile>"
  message "Distributed with tools-for-g09.bash $version ($versiondate)"
  exit 0
fi

is_readable_file_or_exit "$1"
input_chk="$1"

output_fchk="${input_chk%.*}.fchk"
backup_if_exists "$output_fchk"

output_xyz="${input_chk%.*}.xyz"
backup_if_exists "$output_xyz"

# Run the programs
$bin_formchk "$input_chk" "$output_fchk" || fatal "Something went wrong."
$bin_babel -ifchk "$output_fchk" -oxyz -O"$output_xyz" || fatal "Something went wrong."

message "Script complete. Bye!"

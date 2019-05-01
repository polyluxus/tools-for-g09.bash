#!/bin/bash

#####################################################################
#                                                                   #
# Warning: This repository is no longer maintained as Gaussian 09   #
#          is also becoming obsolete, or deprecated.                #
# Info:    The sucessor repository for Gaussian 16 can be found at  #
#          https://github.com/polyluxus/tools-for-g16.bash          #
#                                                                   #
#                                                Martin, 2019-05-01 #
#                                                                   #
#####################################################################

#
#hlp A very quick script to transform a checkpointfile
#hlp to a formatted checkpointfile and then to xyz 
#hlp coordinates using Open Babel.
#hlp Usage: $scriptname [option] <checkpointfile(s)>
#hlp Distributed with tools-for-g09.bash $version ($versiondate)
# 
# This was last updated with 
version="0.1.9"
versiondate="2018-02-15"
# of tools-for-g09.bash

scriptname=${0##*\/} # Remove trailing path
scriptname=${scriptname%.sh} # remove scripting ending (if present)

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
# (-3 for verson 3 fchk; that is the default in the wrapper)
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
    return 1
}

fatal ()
{
    echo "ERROR  : " "$*" >&2
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

is_readable_file_and_warn ()
{
    is_file "$1"     || warning "Specified file '$1' is no file or does not exist."
    is_readable "$1" || warning "Specified file '$1' is not readable."
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
# Format checkpoint file, write xyz coordinates
# a.k.a. run the programs
#

format_one_checkpoint ()
{
    local returncode=0
    local input_chk="$1"
    local output_fchk="${input_chk%.*}.fchk"
    local output_xyz="${input_chk%.*}.xyz"
    
    backup_if_exists "$output_fchk"
    backup_if_exists "$output_xyz"
    
    # Run the programs
    $bin_formchk "$input_chk" "$output_fchk" || returncode="$?"
    if (( returncode != 0 )) ; then
      warning "There was an issue with formatting the checkpointfile."
      return "$returncode"
    fi
    $bin_babel -ifchk "$output_fchk" -oxyz -O"$output_xyz" || (( returncode+=$? ))
    if (( returncode != 0 )) ; then
      warning "There was an issue with writing the coordinates."
      return "$returncode"
    fi

    message "Formatted '$input_chk'; written '$output_xyz'."
}

format_only ()
{
    # run only for commandline arguments
    is_readable_file_and_warn "$1" && format_one_checkpoint "$1" || return $?
}

format_all ()
{
    # run over all checkpoint files
    local input_chk returncode=0
    message "Working on all checkpoint files in ${PWD#\/*\/*\/}." 
    for input_chk in *.chk; do
      [[ "$input_chk" == "*.chk" ]] && fatal "There are no checkpointfiles in this directory."
      format_only "$input_chk" || (( returncode+=$? ))
    done
    return $returncode
}

#
# MAIN SCRIPT
#

exit_status=0
skip_list="false"

(( $# == 0 )) &&  fatal "No checkpointfile specified."

# Initialise options
OPTIND="1"

while getopts :fh options ; do
  case $options in
    #hlp OPTIONS:
    #hlp   -f      Formats all checkpointfiles that are found in the current directory
    f) format_all || exit_status=$?
       skip_list="true"
       ;;
    #hlp   -h      Prints this help text
    h) helpme ;; 

   \?) fatal "Invalid option: -$OPTARG." ;;

    :) fatal "Option -$OPTARG requires an argument." ;;

  esac
done

shift $(( OPTIND - 1 ))

if [[ $skip_list != "true" ]] ; then
  while [[ ! -z $1 ]] ; do
    format_only "$1" || (( exit_status+=$? ))
    shift
  done
fi

(( exit_status == 0 )) || fatal "There have been one or more errors."

message "$scriptname is part of tools-for-g09.bash $version ($versiondate)"

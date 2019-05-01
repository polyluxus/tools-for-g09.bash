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


# This is a wrapper to run gaussian jobs/utilities interactively
#
# CONFIGURATION
#
# Set the paths where the binaries are.
# The following is the g09root directory. 
# If you did not install gaussian yourself, you can run
#   for i in $(locate g09.profile); do echo ${i%\/g09\/*}; done
# and pick the most appropriate location.
gaussian09installpath="/home/chemsoft/gaussian/g09e01"
# The following is only used in the help display.
gaussian09installname="Gaussian 09 Rev. E.01"
# Where shall scratch files be stored.
gaussian09basescratch="/scr/$USER"
# You can use NBO6 in conjunction with Gaussian if you bought it.
# Leave the following empty, if not available.
nbo06bininstallpath="/home/chemsoft/nbo6/nbo6-2016-01-16/bin"
# Do you want to use Gaussview with this script?
# Make sure you have it installed in 
#   $gaussian09installpath/gv/gview
#   for example: /home/chemsoft/gaussian/g09e01/gv/gview (executable)
gaussview="enabled"
# gausview="disabled" # If you can't or won't use it
#
# END CONFIGURATION
###

#hlp $scriptname is a wrapper to access certain utilities from $gaussian09installname
scriptname=${0##*\/} # Remove trailing path
scriptname=${scriptname%.sh} # remove scripting ending (if present)
 
version="0.1.9"
versiondate="2018-02-15"

#
# Avoid conflicts if another Gaussian version is already sourced
# (Especially if that is a different release; g98, g16, etc.
#

check_if_gaussian_is_sourced ()
{
  if [[ ":$PATH:" =~ :([^:]*/(g09|g16)/[^:]*): ]]; then
    message "It appears that a Gaussian is already sourced: ${BASH_REMATCH[1]}."
    message "This will clash with this script."
    fatal "Use native commands instead."
  fi
}

#
# Print logging information and warnings nicely.
# If there is an unrecoverable error: display a message and exit.

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
# Test if a given value is an integer
#

is_integer()
{
    [[ $1 =~ ^[[:digit:]]+$ ]]
}

validate_integer () 
{
    if ! is_integer "$1"; then
        [ ! -z "$2" ] && fatal "Value for $2 ($1) is no integer."
          [ -z "$2" ] && fatal "Value '$1' is no integer."
    fi
}

#
# Script options memory and processes
#

test_and_set_processes ()
{
    requested_processes="$1"
    validate_integer "$requested_processes" "requested processes"
}

test_and_set_memory ()
{
    local test_memory="$1"
    # Gaussian undestands words (no unit) and KB, MB, GB, TB, KW, MW, GW or TW
    local memory_pattern="^([[:digit:]]+)([KkMmGgTt][Bb]|[MmGgTt][Ww])?$"
    if [[ $test_memory =~ $memory_pattern ]] ; then
      requested_memory="${BASH_REMATCH[0]}"
    else
      fatal "Unrecognised input format for memory: $test_memory"
    fi
}

#
# Create a scratch directory for temporary files
#

make_scratch ()
{
  message "Creating new scratch directory."
  gaussian09subscratch="$gaussian09basescratch/g09job.inter$(date +%s)"
  indent
  mkdir -v "$gaussian09subscratch" || fatal "Cannot create temporary scratch directory."
}

#
# Set environment variables, so that the program can be found
#

set_g09_variables ()
{
  message "Initialising $gaussian09installname."
  g09root="$gaussian09installpath"
  message "Using G09: $g09root"
  if [[ -z $gaussian09subscratch ]] ; then
    GAUSS_SCRDIR="$gaussian09basescratch"
  else
    GAUSS_SCRDIR="$gaussian09subscratch"
  fi
  message "Setting scratch directory: $GAUSS_SCRDIR"
  GAUSS_MEMDEF="$requested_memory"
  GAUSS_MDEF="$requested_memory"
  GAUSS_PDEF="$requested_processes"
  message "Setting memory to '$GAUSS_MEMDEF' and processes to '$GAUSS_PDEF'."
  export g09root GAUSS_SCRDIR GAUSS_MEMDEF GAUSS_MDEF GAUSS_PDEF
  . "$g09root/g09/bsd/g09.profile"
  if [[ ! -z "$nbo06bininstallpath" ]] ; then
    nbo6bin="$nbo06bininstallpath"
    message "Using NBO6: $nbo6bin"
    export PATH="$PATH:$nbo6bin"
  fi
}

# If calculation was successful and no auxiliary files were created,
# delete scratch directory
clean_up()
{
  local cleanup_error=0 file skipdelete="false"
  #Cleanup
  if [[ -d "$gaussian09subscratch" ]]; then
    # fix aborting!
    cd "$gaussian09subscratch" || cleanup_error="1"
    if (( cleanup_error > 0 )); then
      warning "Cannot enter temporary scratch directory."
    else
      message "Cleaning $(pwd)"
      for file in *; do
        if [[ -e $file ]]; then
          if [[ -s $file ]]; then
            warning "File '$file' has non-zero filesize, it will be retained."
            skipdelete="true"
            (( cleanup_error++ ))
          else
            message "File '$file' exists, but filesize is zero, it will be deleted."
            indent "  "
            rm -v "$file" || (( cleanup_error++ ))
          fi
        fi
      done
    fi
    cd - > /dev/null
    if [[ ! "$skipdelete" == "true" ]]; then
      message "Removing scratch directory."
      indent "  "
      rmdir -v "$gaussian09subscratch" || (( cleanup_error++ ))
    else
      message "One or more auxiliary files are still left in the temporary scratch directory."
      message "To recover these files issue:"
      message "  mv -v $gaussian09subscratch ."
      message "To delete these files (brutally) issue:"
      message "  rm -rvf $gaussian09subscratch"
    fi
  fi
  (( cleanup_error > 0 )) && warning "There have been one or more errors. Cleanup procedure failed."
  return "$cleanup_error"
}

# Issue warnings if user input is ignored
check_too_many_args ()
{
  while [[ ! -z $1 ]]; do
    warning "Commandlie argument '$1' will be ignored."
    shift
  done
}

# test if a file exists
check_file ()
{
  [[ -f "$1" ]]
}

#
# Main Functions
#

# Perform a calculation
calculation ()
{
  local inputfile="$1"
  shift
  
  check_file "$inputfile" || fatal "Inputfile '$inputfile' does not exist." 
  check_too_many_args "$@"
  
  make_scratch
  set_g09_variables
  
  indent "Start calculation at "
  date
  g09 "$inputfile"
  # Alternative way of letting Gaussian set the environment variables:
  # g09 -m="$requested_memory" -p="$requested_processes" "$inputfile"
  joberror=$?
  indent "End   calculation at "
  date
  
  clean_up 
}

# Produce a formatted checkpointfile
format_checkpoint ()
{
  local option=""
  local pattern="^(-c|-2|-3)$"
  if [[ "$1" =~ $pattern ]] ; then
    option="${BASH_REMATCH[1]}"
    if [[ "$2" =~ $pattern ]] ; then
      warning "Additional option '${BASH_REMATCH[1]}' is ignored (they are exclusive)."
      # Or are they? At least -2 and -3 doesn't make sense.
      shift
    fi
    shift
  else
    option="-3"
  fi

  set_g09_variables
  if [[ -z $1 ]]; then 
    formchk "$option"
    joberror=$?
    return
  fi 

  local input_checkpoint="$1" 
  local output_checkpoint
  shift
  check_file "$input_checkpoint" || fatal "Checkpointfile '$input_checkpoint' does not exist."

  if [[ -z $1 ]] ; then
    output_checkpoint="${input_checkpoint%.chk}.fchk"
  else
    output_checkpoint="$1"
    shift
    check_too_many_args "$@"
  fi
  formchk "$option" "$input_checkpoint" "$output_checkpoint"
  joberror=$?
}

# Produce a binary checkpointfile 
unformat_checkpoint ()
{
  set_g09_variables
  if [[ -z $1 ]] ; then 
    unfchk
    joberror=$?
    return
  fi 
  local input_checkpoint="$1" 
  local output_checkpoint
  shift
  check_file "$input_checkpoint" || fatal "Formatted checkpointfile '$input_checkpoint' does not exist."
  if [[ -z $1 ]]; then
    output_checkpoint="${input_checkpoint%.fchk}.chk"
  else
    output_checkpoint="$1"
    shift
    check_too_many_args "$@"
  fi
  unfchk "$input_checkpoint" "$output_checkpoint"
  joberror=$?
}

# produces cube files for plotting and calculating
generate_cubefiles ()
{
  message "No sanity check will be performed, please consult the manual."
  set_g09_variables
  cubegen "$@" 
  joberror=$?
}

use_bare_wrapper ()
{
  message "This interface can be used to access any command available from g09."
  message "No sanity check will be performed, please consult the manual."
  [[ -z $1 ]] &&  fatal "No input provided. Nothing to do."
  set_g09_variables
  "$@" 
  joberror=$?
}

load_bash ()
{
  message "This interface loads the Gaussian environment variables,"
  message "and opens a bash shell."
  check_too_many_args "$@"
  set_g09_variables
  bash
  joberror=$?
}

load_gaussview ()
{
  local gaussviewbin="$gaussian16installpath/gv/gview"
  if [[ ! $gaussview == "enabled" ]] ; then
    warning "GaussView is disabled through the configuration of this script."
    joberror=1
  elif [[ -f "$gaussviewbin" && -x "$gaussviewbin" ]] ; then
    message "This interface loads the Gaussian environment variables,"
    message "and opens GaussView 5."
    set_g16_variables
    "$gaussviewbin" "$@"
    joberror=$?
  else
    fatal "GaussView does not exist in '$gaussviewbin'."
  fi
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

execute_commandline ()
{
    case "$1" in
      "formchk" | "formcheck" ) 
                 shift; format_checkpoint "$@" ;;
      
       "unfchk" | "unformcheck" ) 
                 shift; unformat_checkpoint "$@" ;;
      
      "cubegen") shift; generate_cubefiles "$@" ;;
      
          "raw") shift; use_bare_wrapper "$@" ;;
      
         "bash") shift; load_bash "$@" ;;

           "gv" | "view") 
                 shift; load_gaussview "$@" ;;
      
              *) calculation "$@" ;;
    esac
}

set_longoption ()
{
    if [[ -z $longoption ]] ; then
      longoption="$1"
    else
      fatal "Specified commands '$longoption' and '$1' are mutually exclusive."
    fi
}

evaluate_options ()
{
    # Initialise options
    local OPTIND="1"
    
    while getopts :fucrbVm:p:h options ; do
      #hlp Usages and options:
      #hlp $scriptname [scriptoptions] commands (see below)
      #hlp
      #hlp Run a calculation:
      #hlp   $scriptname <inputfile>
      #hlp   When provided with and Gaussian inputfile, the wrapper will initialise
      #hlp   the Gaussian environment and perform a calculation.
      #hlp   (No sanity check of the file will be performed.)
      #hlp

      case $options in
        #hlp  Format a checkpointfile
        #hlp    $scriptname ( -f | formchk | formcheck ) [option] [<input>] [<output>]
        #hlp    Calls the G09 utility formchk with the default option -3 (see manual).
        #hlp    Possible values for option (exclusive): -3, -2, -c.
        #hlp    Input and output are optional arguments, if not present, they will be 
        #hlp    prompted for or guessed.
        #hlp    (No sanity check of the file will be performed.)
        #hlp
        f) set_longoption "formchk" ;;

        #hlp Create a binary checkpointfile:k
        #hlp   $scriptname ( -u | unfchk | unformcheck ) [<input>] [<output>]
        #hlp   Calls the G09 utility unfchk (see manual).
        #hlp   Input and output are optional arguments, if not present, they will be
        #hlp   prompted for or guessed.
        #hlp   (No sanity check of the file will be performed.)
        #hlp 
        u) set_longoption "unfchk" ;;

        #hlp Create a cube file:
        #hlp   $scriptname ( -c | cubegen ) [parameters]
        #hlp   Calls the G09 utility cubegen (see manual).
        #hlp   No sanity check of parameters will be performend.
        #hlp   General syntax:
        #hlp     cubegen nprocs kind fchkfile cubefile npts format cubefile2
        #hlp   Example command:
        #hlp     $scriptname cubegen 1 MO=HOMO test.fchk test.cube 80 h
        #hlp     (Will use one process, writes the HOMO from test.fchk to test.cube
        #hlp      with 80 points per side of the cube including header.)
        #hlp
        c) set_longoption "cubegen" ;;

        #hlp Execute custom commands:
        #hlp   $scriptname ( -r | raw ) [command(s)]
        #hlp   This is the free-form option of the wrapper.
        #hlp   It can be used with any command(s), it only temporarily loads the g09 
        #hlp   environment. See the Gaussian manual for more information.
        #hlp
        r) set_longoption "raw" ;;

        #hlp Load bash session:
        #hlp   $scriptname ( -b | bash )
        #hlp   Loads the environment settings and then opens a bash subshell.
        #hlp   You can pretty much run any command with that. 
        #hlp
        b) set_longoption "bash" ;;

        #hlp Load GaussView:
        #hlp   $scriptname ( -V | gv | view ) [parameters]
        #hlp   Any parameters are optional and will be passed on to GaussView,
        #hlp   see the manual for more information.
        #hlp   (Must be enebled in the configuration.)
        #hlp
        V) set_longoption "gv" ;;

        #hlp Scriptoptions:
        #hlp   -m <ARG>  Set memory variables GAUSS_MEMDEF and GAUSS_MDEF.
        #hlp             The argument is taken to be in words, but can be modified
        #hlp             with the following units the script understands: b, kb, mb, gb, mw
        #hlp             The default setting is '$requested_memory'.
        #hlp             (Depending on the utility this might have no effect.)
        #hlp
        m) test_and_set_memory "$OPTARG" ;;

        #hlp   -p <ARG>  Set processes variable GAUSS_PDEF.
        #hlp             The argument has to be an integer, '$requested_processes' is the default.
        #hlp             (Depending on the utility this might have no effect.)
        #hlp 
        p) test_and_set_processes "$OPTARG" ;;

        #hlp   -h        Prints this help text
        #hlp
        h) helpme ;; 
    
       \?) fatal "Invalid option: -$OPTARG." ;;
    
        :) fatal "Option -$OPTARG requires an argument." ;;
    
      esac
    done

    shift $(( OPTIND - 1 ))
    commandline=($longoption "$@")
}

#
# MAIN SCRIPT
#

check_if_gaussian_is_sourced

# Set some defaults
longoption=""
requested_memory="4GB"
requested_processes="1"
declare -a commandline
joberror=0

evaluate_options "$@"
(( ${#commandline[@]} == 0 )) && helpme
execute_commandline "${commandline[@]}"

message "$scriptname is part of tools-for-g09.bash $version ($versiondate)"
# If the programs fail, the exit status of the script should reflect that.
#hlp Exit status is zero if everything went fine.
#hlp In other cases it reflects the exit status of the utility.
#hlp
exit $joberror
#hlp (Martin; $version; $versiondate)

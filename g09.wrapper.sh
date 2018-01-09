#!/bin/bash

scriptname=${0##*\/} # Remove trailing path
scriptname=${scriptname%.sh} # remove scripting ending (if present)
 
version="0.1.2"
versiondate="2017-12-19"

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
#
# END CONFIGURATION
###

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

# Create a scratch directory for temporary files
make_scratch ()
{
  message "Creating new scratch directory."
  gaussian09subscratch="$gaussian09basescratch/g09job.inter$(date +%s)"
  indent
  mkdir -v "$gaussian09subscratch" || fatal "Cannot create temporary scratch directory."
}

# Set environment variables, so that the program can be found
# This routine needs to be adjusted based on the actual path locations
set_g09_variables ()
{
  message "Initialising Gaussian 09."
  g09root="$gaussian09installpath"
  message "Using $g09root"
  GAUSS_SCRDIR="$gaussian09subscratch"
  export g09root GAUSS_SCRDIR
  . "$g09root/g09/bsd/g09.profile"
  if [[ ! -z "$nbo06bininstallpath" ]] ; then
    nbo6bin="$nbo06bininstallpath"
    message "Using NBO6 $nbo6bin"
    export PATH="$PATH:$nbo6bin"
  fi
}

# If calculation was successful and no auxiliary files were created,
# delete scratch directory
clean_up()
{
  #Cleanup
  if [[ -d "$gaussian09subscratch" ]]; then
    cd "$gaussian09subscratch" || fatal "Cannot enter temporary scratch directory."
    for file in *; do
      if [[ -e $file ]]; then
        if [[ -s $file ]]; then
          message "$file does exist and its filesize is greater than zero."
          local skipdelete="true"
        else
          message "$file does exist but its filesize is zero. It will be deleted."
          indent "  "
          rm -v "$file"
        fi
      fi
    done
    cd - > /dev/null
    if [[ ! "$skipdelete" == "true" ]]; then
      message "Removing scratch directory."
      indent "  "
      rmdir -v "$gaussian09subscratch"
    else
      message "One or more auxiliary files are still left in the temporary scratch directory."
      message "To recover these files issue:"
      message "  mv -v $gaussian09subscratch ."
      message "To delete these files (brutally) issue:"
      message "  rm -rvf $gaussian09subscratch"
    fi
  fi
}

# Issue warnings if user input is ignored
check_too_many_args ()
{
  while [[ ! -z $1 ]]; do
    warning "$1 will be ignored."
    shift
  done
}

# test if a file exists
check_file ()
{
  [[ -f "$1" ]]
#Schould return the same as
#  if [[ -f $1 ]]; then 
#    return 0
#  else
#    return 1
#  fi
}

#
# Main Functions
#

# Perform a calculation
calculation ()
{
  check_file "$1" || fatal "$1 does not exist." 
  
  make_scratch
  set_g09_variables
  
  inputfile="$1"
  shift
  
  check_too_many_args "$@"
  
  indent "Start calculation at "
  date
  g09 "$inputfile"
  joberror=$?
  indent "End   calculation at "
  date
  
  clean_up
}

# Produce a formatted checkpointfile
format_checkpoint ()
{
  local option=""
##  case $1 in
##    -3) option="-3"; shift ;;
##    -2) option="-2"; shift ;;
##    -c) option="-c"; shift ;;
##     *) option="-3" ;;
##  esac
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

  if [[ -z $1 ]]; then 
    formchk "$option"
    joberror=$?
    return
  fi 

  check_file "$1" || fatal "$1 does not exist."
  input_checkpoint="$1" 
  shift

  if [[ -z $1 ]] ; then
    output_checkpoint="${input_checkpoint%.chk}.fchk"
  else
    output_checkpoint="$1"
    shift
    check_too_many_args "$@"
  fi
  set_g09_variables
  formchk "$option" "$input_checkpoint" "$output_checkpoint"
  joberror=$?
}

# Produce a binary checkpointfile 
unformat_checkpoint ()
{
  if [[ -z $1 ]] ; then 
    unfchk
    joberror=$?
    return
  fi 
  check_file "$1" || fatal "$1 does not exist."
  input_checkpoint="$1" 
  shift
  if [[ -z $1 ]]; then
    output_checkpoint="${input_checkpoint%.fchk}.chk"
  else
    output_checkpoint="$1"
    shift
    check_too_many_args "$@"
  fi
  set_g09_variables
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

print_help ()
{
cat <<- EOF
$scriptname is a wrapper to access certain utilities from $gaussian09installname

Usages:

  $scriptname <inputfile>
    When provided with and Gaussian inputfile, the wrapper will initialise
    the Gaussian environment and perform a calculation.
    (No sanity check of the file will be performed.)

  $scriptname formchk [option] [<input>] [<output>]
    Calls the G09 utility formchk with the default option -3 (see manual).
    Possible values for option (exclusive): -3, -2, -c.
    Input and output are optional arguments, if not present, they will be 
    prompted for or guessed.
    (The option 'formcheck' is a synonym for 'formchk'.)
    (No sanity check of the file will be performed.)

  $scriptname unfchk [<input>] [<output>]
    Calls the G09 utility unfchk (see manual).
    Input and output are optional arguments, if not present, they will be
    prompted for or guessed.
    (The option 'unformcheck' is a synonym for 'unfchk'.)
    (No sanity check of the file will be performed.)

  $scriptname cubegen [parameters]
    Calls the G09 utility cubegen (see manual).
    No sanity check of parameters will be performend.
    General syntax:
      cubegen nprocs kind fchkfile cubefile npts format cubefile2
    Example command:
      $scriptname cubegen 1 MO=HOMO test.fchk test.cube 80 h
      (Will use one process, writes the HOMO from test.fchk to test.cube
       with 80 points per side of the cube including header.)

  $scriptname raw [command(s)]
    This is the free-form option of the wrapper.
    It can be used with any command(s), it only temporarily loads the g09 
    environment. See the manual for more information.

  $scriptname bash
    Loads the environment settings and then opens a bash subshell.
    You can pretty much run any command with that. 

This 'software' comes with absolutely no warrenty. None. Nada. 

(Martin; $version; $versiondate.)
EOF

exit 0
}

#
# MAIN SCRIPT
#

check_if_gaussian_is_sourced

# Implement to set memory via GAUSS_MEMDEF

case "$1" in
  # If no input, print short message.
              "") message "Use '$scriptname help' to get a brief overview."
                  fatal   "Please specify an input file or command." ;;
     
       "formchk" | "formcheck" ) 
                  shift; format_checkpoint "$@" ;;
     
        "unfchk" | "unformcheck" ) 
                  shift; unformat_checkpoint "$@" ;;
     
       "cubegen") shift; generate_cubefiles "$@" ;;
     
           "raw") shift; use_bare_wrapper "$@" ;;
      
          "bash") shift; load_bash "$@" ;;
     
   "-h" | "help") print_help ;;
     
               *) calculation "$@" ;;
esac

message "$scriptname completed."
# If the programs fail, the exit status of the script should reflect that.
exit $joberror


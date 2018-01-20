# tools-for-g09.bash

Various bash scripts to aid the use of the quantum chemistry software 
package Gaussian 09.

Install them simply by downloading them and making them executable.
I prefer having them in `~/scripts` and adding that directory to
my PATH variable. But that is just a question of taste.   
In few occasions path names to binaries might have to be adjusted. 
See the header of the files for more details and necessary 
configuration.

Some of the content has been reviewed at 
https://codereview.stackexchange.com/

Please understand, that this project is primarily for me to help my everyday 
work. I am happy to hear about suggestions and bugs. I am fairly certain, 
that it will be a work in progress for quite some time and might be 
therefore in constant flux.
This 'software' comes with absolutely no warrenty. None. Nada. 

There is also absolutely no warranty in any case. If you decide to use any 
of the scripts, it is entirely your resonsibility. :D

Thank you for your interest.

---

Short overview and introduction of the bundle scripts and files.
Most scripts come with a `-h` option for a short description, that should
always work, regardless of the set paths.

With the release of Gaussian 16, all names have been prepended with g09.

### g09.getenergy.sh

This tool can be used to create a summary of the log files in a directory.
It can be used on any file by explicitly stating those on the commandline.
Doing this will skip writing a header and is therefore just a preformatted
grep on the energy.  
The original intention is to create a quick overview over the calculations 
in one directory, esp. if calculations have been carried out for multiple 
methods.   
If no argument is supplied the script will look for all `*.com` files in
the current directory. It will try to match a corresponding `*.log` file.
It then looks for the last energy statement and formats it as a table.
See also http://codereview.stackexchange.com/q/129854/92423

To Do:
 - Includeoptions for more file suffixes
 - write to file istead of stout
 - include timestamp of file
 - etc.

### g09.getfreq.sh

This tool creates a summary for a single (or more) frequency calculation(s). 
It will, however, not fail if it is not one. In principle it looks for a defined 
set of keywords and writes them to the screen.   
The level of verbosity can be entered directly with `-V(0,1,2,3)` or increased 
stepwise with `-v`. Comma seperated values are available with `-c.`
See also http://codereview.stackexchange.com/q/131666/92423

To Do: 

 - include customised outputline (specify which quantities are printed)
 - review of the code and extended testing (review implemented) 
 - fix bug when locale is not set to English (temprorarily set to `en_US.utf8` done) 
 - script does not properly work for mp2 (..) calculations, as it does not 
   fetch the appropriate corrections
 - etc.

### g09.chk2xyz.sh

This script uses a (binary) checkpointfile, writes a formatted
checkpointfile, and uses Open Babel to write xyz coordinates.
This script has to be configured to find the right executables, 
and needs a recent installation of Open Babel. (Who'd have guessed?!)

The `-f` switch looks for all checkpoint files, formats them, and 
extracts the coordinates. This can be very helpful for archiving 
calculations.

### g09.wrapper.sh

This script is a wrapper to access certain utilities from Gaussian 09.
Some configuration is required for it to work, i.e. it has to find the
correct Gaussian directory, the scratch directory, and the NBO6 
directory (optional).   
Several modes have been predefined for convenience.
They are accessible via short options and keywords.
In general no sanity check on the inputfiles will be performed.

General usage:
```
  g09.wrapper [scriptoptions] commands
```
Scriptoptions can be used to set memory requirements `-m` or processes `-p`. 
Depending on the command used these may or may not have an effect.
Use the `-h` switch to get more information.

The following shortcuts have been implemented.
```
  g09.wrapper <inputfile>
```
When provided with and Gaussian inputfile, the wrapper will initialise
the Gaussian environment and perform a calculation.

```
  g09.wrapper ( -f | formchk | formcheck ) [option] [<input>] [<output>]
```
Calls the G09 utility `formchk` with the default option `-3` (see Gaussian manual).
Possible values for options (exclusive): `-3`, `-2`, `-c`.
Input and output are optional arguments, if not present, they will be 
prompted for or guessed.  

```
  g09.wrapper ( -u | unfchk | unformcheck ) [<input>] [<output>]
```
Calls the G09 utility unfchk (see Gaussian manual).
Input and output are optional arguments, if not present, they will be
prompted for or guessed.  

```
  g09.wrapper ( -c | cubegen ) [parameters]
```
Calls the G09 utility cubegen (see manual).    
No sanity check of parameters will be performend.  
General syntax:  
`cubegen nprocs kind fchkfile cubefile npts format cubefile2`  
Example command:   
`g09.wrapper cubegen 1 MO=HOMO test.fchk test.cube 80 h`  
(Will use one process, writes the HOMO from test.fchk to test.cube
 with 80 points per side of the cube including header.)

```
  g09.wrapper ( -r | raw ) [command(s)]
```
This is the free-form option of the wrapper.
It can be used with any command(s), it only temporarily loads the g09 
environment. See the Gaussian manual for more information.

```
  g09.wrapper ( -b | bash )
```
Loads the environment settings and then opens a bash subshell.
You can pretty much run any command with that. 

To Do:
 - Implement option to set `GAUSS_MEMDEF` for the utilities. Currently 
 if memory is scarce you need to use raw or bash mode.

### g09.propwfx.sh (used to be g09.genwfx.sh)

This script reads an inputfile and produces a new inputfile to perform a property run.
In such a run no calculation will be performed, therefore a checkpointfile is
strictly neccessary. It also is possible to run these calculations interactively
with the wrapper script, as they should only take a few minutes at most.

The `-n` switch requests to write the older version `wfn` (PROAIMS) instead of
the newer extended `wfx` (AIMPAC) files.

(A symbolic link to g09.genwfx.sh is retained for now.)

### g09.propnbo6.sh

This script takes a Gaussian inputfile and writes a new inputfile for a property run,
a NBO6 analysis, similar to g09.propwfx above.
The newly created inputfile relies on a checkpointfile to read all data for the NBO6 analysis.
Depending on the size of the molecule, a NBO analysis can take some time.

Additional Input can be given to be processed via `-n` (NBO input stack), 
`-r` (Route section), and `-t` (tail of the file).

### examples (directory; used to be water.sample.tgz)

Contains a collection of Gaussian 09 in- and outputs for demonstration
and testing. Mainly the files I have used to test the scripts.

---

more tools in preparation (?)

(Martin; 0.1.5; 2018-01-19)

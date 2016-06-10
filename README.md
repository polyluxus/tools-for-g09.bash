tools-for-g09

Various bash scripts to aid the use of the quantum chemistry software package Gaussian 09.

Install them simply by downloading them. In few occasions path names might have to be 
adjusted. See the header of the files you are interested in for more details.

Some of the content has been reviewed at http://codereview.stackexchange.com/

Please understand, that this project is primarily for me to help my everyday work. I am
happy to hear about suggestions and bugs. I am fairly certain, that it will be a work in 
progress for quite some time and might be therefore in constant flux.

There is also absolutely no warranty in any case. If you decide to use any of the code,
it is your resonsibility. :D

Thank you for your interest.

---

Short overview and introduction of the  bundle files

getenergy.sh

This tool can be used to create a summary of the log files in a directory.
It can be used on any file by explicitly stating those on the commandline.
Doing this will skip writing a header and is therefore just a preformatted
grep on the energy.
The original intention is to create a quick overview over the calculations 
in one directory, esp. if calculations have been carried out for multiple 
methods. 
If no argument is supplied the script will look for all *.com files in
the current directory. It will try to match a corresponding *.log file.
It then looks for the last energy statement and formats it as a table.
See also http://codereview.stackexchange.com/q/129854/92423

To Do: - Includeoptions for more file suffixes
       - write to file istead of stout
       - include timestamp of file
       - include a switch to be able to search from the start
       - etc.

---

getfreq.sh

This tool creates a summary for a single (or more) frequency calculation(s). It will, 
however, not fail if it is not one. In principle it looks for a defined 
set of keywords and writes them to the screen.
The level of verbosity can be enetered directly with -V(0,1,2,3) or increased step-
wise with -v. Comma seperated values are available with -c.

To Do: - write proper usage and help functions
       - include customised outputline (specify which quantities are printed)
       - review of the code and extended testing
       - etc.

---

more tools in preparation


#!/bin/csh
#
# Script to automatically compute tidal coefficients, parse and fill
# the fort.15.template file.
# See adcirc.org documentation for fort.15 for more info
# Method heavily borrowed from Jason Fleming's ASGS scripts
# (https://github.com/jasonfleming/asgs)
#
# Steps:  1) Edit the USER INPUT section of this script
#         2) Execute at command line:
#            >> ./fill_fort15_tides.csh
#
# Input:  Modify script variables in USER INPUT
#         Built tide_fac.f program, e.g. tide_fac_asga.exe
#         fort.15.template file 
#
# Output: fort.15   -- control file with new tidal info for 
#                      use in ADCIRC
#         diags.out -- useful info from execution
#
# Author: Kate Fossell
# Contact: fossell@ucar.edu
# Last Udate: 9 Oct 2018
#    Modified to be used to run with ECMWF forcing.
#    Some fields hard coded, use with caution.
#--------BEGIN USER INPUT-----------#

# Additional fort.15 configure settings for ecmwf
 set runid = "ecmwf irma ens $1"
 set ihot = 367
 set met_ramp_delay = 18.5

# new call to python scripts to strip out the fhrs for rnday
  python ~fossell/adcirc/scripts/getFhrs.py $1 $met_ramp_delay

 # Set the date/time information
   set ihr   = 00
   set idy   = 21
   set imn   = 08
   set iyr   = 2017
  #set rnday = 22.75
   set rnday = `cat EE$1_fhrs.txt`
   set stormnum = 11

 # Set the names of the template file and desired
 # output filename. Full paths.
  set f15_tmpl = "/gpfs/fs1/scratch/fossell/ADCIRC/IRMA/ecmwf/fort.15.nos.nws19.template"
  set f15_outp = "./fort.15"

 # If needed, modify the number of constituents
 # and the names of the constituents. * This 
 # depends on the specific grid, e.g. NOS 
 # Executable is hard coded to handle these 13.
  set ncon  = 13
  set cons  = ( K1 O1 P1 Q1 N2 M2 S2 K2 \
                MF MM M4 MS4 MN4 ) 

# Executable path and name
  set tide_exe = /gpfs/u/home/fossell/adcirc/utilities/tide_fac_asgs.exe

#---------END USER INPUT-------------#

# Remove old stff
  if ( -e fort.15 )      rm fort.15
  if ( -e diags.out)     rm diags.out
  if ( -e tide_face.out) rm tide_fac.out

# Initialize some arrays
  set NF_list = (${cons})
  set QARG_list = (${cons})

# Compute tidal coefficients using input above
# Uses variables from USER INPUT and outputs constituents in
# file called tide_fac.out.
$tide_exe --length $rnday --year $iyr --month $imn --day $idy --hour $ihr --outputformat simple  >> diags.out

cat tide_fac.out >> diags.out

# Parse out tidal coefficients from tide_fac.out and store in variables
@ n = 1
while ($n <= $#cons)

 set tide = $cons[$n]
 set NF_list[$n]   = `grep $tide tide_fac.out | awk '{print $2}'`   # Nodal Factor (NF)
 set QARG_list[$n] = `grep $tide tide_fac.out | awk '{print $3}'`   # Equilibrium Argument (QARG)

 @ n ++
end

# Fill template fort.15 with variables 
# input: variables from step 2 and fort.15.template
# output: fort.15

sed -e "s/%${cons[1]}NF%/$NF_list[1]/g" -e "s/%${cons[1]}QARG%/$QARG_list[1]/g" \
    -e "s/%${cons[2]}NF%/$NF_list[2]/g" -e "s/%${cons[2]}QARG%/$QARG_list[2]/g" \
    -e "s/%${cons[3]}NF%/$NF_list[3]/g" -e "s/%${cons[3]}QARG%/$QARG_list[3]/g" \
    -e "s/%${cons[4]}NF%/$NF_list[4]/g" -e "s/%${cons[4]}QARG%/$QARG_list[4]/g" \
    -e "s/%${cons[5]}NF%/$NF_list[5]/g" -e "s/%${cons[5]}QARG%/$QARG_list[5]/g" \
    -e "s/%${cons[6]}NF%/$NF_list[6]/g" -e "s/%${cons[6]}QARG%/$QARG_list[6]/g" \
    -e "s/%${cons[7]}NF%/$NF_list[7]/g" -e "s/%${cons[7]}QARG%/$QARG_list[7]/g" \
    -e "s/%${cons[8]}NF%/$NF_list[8]/g" -e "s/%${cons[8]}QARG%/$QARG_list[8]/g" \
    -e "s/%${cons[9]}NF%/$NF_list[9]/g" -e "s/%${cons[9]}QARG%/$QARG_list[9]/g" \
    -e "s/%${cons[10]}NF%/$NF_list[10]/g" -e "s/%${cons[10]}QARG%/$QARG_list[10]/g" \
    -e "s/%${cons[11]}NF%/$NF_list[11]/g" -e "s/%${cons[11]}QARG%/$QARG_list[11]/g" \
    -e "s/%${cons[12]}NF%/$NF_list[12]/g" -e "s/%${cons[12]}QARG%/$QARG_list[12]/g" \
    -e "s/%${cons[13]}NF%/$NF_list[13]/g" -e "s/%${cons[13]}QARG%/$QARG_list[13]/g" \
    -e "s/%RUNID%/$runid/g"  \
    -e "s/%IHOT%/$ihot/g"  \
    -e "s/%IYR%/$iyr/g"  \
    -e "s/%IMN%/$imn/g"  \
    -e "s/%IDY%/$idy/g"  \
    -e "s/%IHR%/$ihr/g"  \
    -e "s/%IST%/$stormnum/g"  \
    -e "s/%RNDAY%/$rnday/g" \
    -e "s/%MET_RAMP_DELAY%/$met_ramp_delay/g" \
    -e "s/%BASEDATE%/$iyr-$imn-$idy ${ihr}:00:00 UTC/g" \
    ${f15_tmpl}  >  ${f15_outp}


exit

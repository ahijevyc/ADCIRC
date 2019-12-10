#!/bin/csh

set desc="vmax_from_besttrack"
set desc="besttrack_minp_vmax_at_25.2N"
# Control member CF00 and Perturbed members PF01-PF50
foreach f ( `seq -w 0 50` )
    set F="PF"
    if ($f == "00") set F="CF"
    grep " EE$f, " /glade/work/ahijevyc/atcf/archive/2017/aal112017.ecmwf.ens.dat | grep " 2017090812, 03," > t.dat
    python ~/bin/interpolate_atcf.py t.dat 6H --hack
    mv -vi /glade/scratch/ahijevyc/temp/t.atcf ECMWF.0p125.nws19.$desc.2017090812.$F$f/fort.22
    if ($status != 0) break
end

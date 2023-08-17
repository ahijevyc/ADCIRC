#!/bin/csh

set description=vmax_from_besttrack
set description=besttrack_vmax_at_25.2N
set description=besttrack_minp_vmax_at_25.2N
foreach f ( `seq -w 0 50` )
    grep " EE$f, " /glade/work/ahijevyc/atcf/Irma2017/0p125/aal112017.ecmwf.ens.dat_origmeshTrue | grep " 2017090812, 03," > t.dat
    # got the dates by finding the first time Irma is at or north of 25.2N
    # ~ahijevyc/bin/first_time_north_of_latitude.py is the script.
    if($f == 00) set landfall=2017091019
    if($f == 01) set landfall=2017091100
    if($f == 02) set landfall=2017091013
    if($f == 03) set landfall=2017091014
    if($f == 04) set landfall=2017091021
    if($f == 05) set landfall=2017091012
    if($f == 06) set landfall=2017091019
    if($f == 07) set landfall=2017091017
    if($f == 08) set landfall=2017091019
    if($f == 09) set landfall=2017091018
    if($f == 10) set landfall=2017091017
    if($f == 11) set landfall=2017091013
    if($f == 12) set landfall=2017091020
    if($f == 13) set landfall=2017091020
    if($f == 14) set landfall=2017091008
    if($f == 15) set landfall=2017091023
    if($f == 16) set landfall=2017091011
    if($f == 17) set landfall=2017091017
    if($f == 18) set landfall=2017091014
    if($f == 19) set landfall=2017091019
    if($f == 20) set landfall=2017091011
    if($f == 21) set landfall=2017091015
    if($f == 22) set landfall=2017091018
    if($f == 23) set landfall=2017091020
    if($f == 24) set landfall=2017091011
    if($f == 25) set landfall=2017091011
    if($f == 26) set landfall=2017091017
    if($f == 27) set landfall=2017091017
    if($f == 28) set landfall=2017091014
    if($f == 29) set landfall=2017091018
    if($f == 30) set landfall=2017091017
    if($f == 31) set landfall=2017091013
    if($f == 32) set landfall=2017091023
    if($f == 33) set landfall=2017091018
    if($f == 34) set landfall=2017091020
    if($f == 35) set landfall=2017091020
    if($f == 36) set landfall=2017091015
    if($f == 37) set landfall=2017091008
    if($f == 38) set landfall=2017091103
    if($f == 39) set landfall=2017091017
    if($f == 40) set landfall=2017091019
    if($f == 41) set landfall=2017091012
    if($f == 42) set landfall=2017091021
    if($f == 43) set landfall=2017091016
    if($f == 44) set landfall=2017091021
    if($f == 45) set landfall=2017091011
    if($f == 46) set landfall=2017091017
    if($f == 47) set landfall=2017091020
    if($f == 48) set landfall=2017091015
    if($f == 49) set landfall=2017091019
    if($f == 50) set landfall=2017091014

    python ~/bin/replace_vitals_atcf.py t.dat 6H --landfall 2017091019 $landfall --minp /glade/work/ahijevyc/atcf/archive/2017/bal112017.dat --vmax /glade/work/ahijevyc/atcf/archive/2017/bal112017.dat   
    if ($status != 0) break
    set F=PF
    if ($f == 00) set F=CF
    set odir=/glade/work/ahijevyc/ADCIRC/IRMA/ECMWF.0p125.nws19.$description.2017090812.$F$f
    mkdir -pv $odir
    mv -v /glade/scratch/ahijevyc/temp/t.atcf $odir/fort.22
    cp -v $odir/fort.22 /glade/scratch/ahijevyc/ECMWF/0p125/nws19/$description/2017090812/2017090812_EE$f
    if ($status != 0) break
end

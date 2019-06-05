#!/bin/csh

module load python
ncar_pylib
set echo
set i=2017090812
foreach f (`seq -w 1 50` CO)
    cd /glade/work/ahijevyc/ADCIRC/IRMA
    set wdir=WRF.$i.EPS_$f.27km3km
    mkdir $wdir

    # Hack for undone tracks
    #cp control_nws20_newtides*/fort.22 $wdir
    #continue

    cd $wdir

    #rm maxele.63.nc .
    cp -v /glade/scratch/ahijevyc/kowaleski/$i/EPS_${f}/fort.61.nc .
    #continue

    #set tfile=E${f}_track1hr.txt
    #lwp-download http://tc.met.psu.edu/Irma/090812/Tracks/1hr/$tfile
    #rename E EPS $tfile
    cd ..
    #python /glade/work/ahijevyc/ADCIRC/IRMA/convert_1hrtxt2.py $wdir

end

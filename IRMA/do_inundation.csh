#!/bin/sh

# grep sbatch from output.

A=P64000499
A=NMMM0021
stormname=IRMA
for minus_tide in False ; do 
    for dryland in "MHHW"; do
    #for f in nws20.2017090812.EPS_14.27km3km WRF.2017090812.EPS_14.27km3km; do
        for f in ECMWF.0p125.nws19.2017090812.?*; do
            echo "#!/bin/csh" > cmd.$f.exe
            echo module load ncl >> cmd.$f.exe
            echo setenv NCL_DEF_LIB_DIR /glade/u/home/ahijevyc/src/ncl_shared_objects/ | tee -a cmd.$f.exe
            echo ncl \'dryland=\"$dryland\"\' \'stormname=\"$stormname\"\' minus_astronomical_tide=$minus_tide \'modelstr=\"$f\"\' \'region=\"FloridaSW\"\' ymax=0.5 /glade/work/ahijevyc/ADCIRC/inundation_timeseries.ncl | tee -a cmd.$f.exe
            echo ncl \'dryland=\"$dryland\"\' \'stormname=\"$stormname\"\' minus_astronomical_tide=$minus_tide \'modelstr=\"$f\"\' \'region=\"FloridaNE\"\' ymax=4 /glade/work/ahijevyc/ADCIRC/inundation_timeseries.ncl | tee -a cmd.$f.exe
            echo sbatch -n 1 -t 128 --mem=10900 -A $A -J $f -p dav cmd.$f.exe \; sleep 10
        done
    done
done

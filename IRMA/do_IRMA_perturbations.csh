#!/bin/sh

stormname=IRMA
for minus_tide in True ; do 
    for dryland in "MHHW"; do
        for f in nws19.control coldstart_extend nws19.rmax+100 nws19.rmax-20 nws19.rmax+25 nws19.rmax-33 nws19.rmax-43 nws19.rmax-50 nws19.rmax+50 nws19.rmax+75 nws19.veer-7 nws19.veer-6 nws19.veer-5 nws19.veer-4 nws19.veer-3 nws19.veer-2 nws19.veer-1 nws19.veer+1 nws19.veer+2 nws19.veer+3 nws19.veer+4 nws19.veer+5 nws19.veer+6 nws19.veer+7 nws19.speed-20 nws19.speed-15 nws19.speed+15 nws19.speed-10 nws19.speed+10 nws19.speed+20 nws19.speed-5 nws19.speed+5 nws19.vmax-7 nws19.vmax+7 nws19.vmax-5 nws19.vmax+5 nws19.vmax-3 nws19.vmax+3 nws19.vmax-1 nws19.vmax+1; do
            echo "#!/bin/csh" > cmd.$f.exe
            echo source /glade/u/apps/opt/slurm_init/init.csh >> cmd.$f.exe
            echo module load ncl >> cmd.$f.exe
            echo setenv NCL_DEF_LIB_DIR /glade/u/home/ahijevyc/src/ncl_shared_objects/ | tee -a cmd.$f.exe
            echo ncl \'dryland=\"$dryland\"\' \'stormname=\"$stormname\"\' minus_astronomical_tide=$minus_tide \'modelstr=\"$f\"\' \'region=\"FloridaSW\"\' /glade/work/ahijevyc/ADCIRC/perfect_cntl.ncl | tee -a cmd.$f.exe
            echo ncl \'dryland=\"$dryland\"\' \'stormname=\"$stormname\"\' minus_astronomical_tide=$minus_tide \'modelstr=\"$f\"\' \'region=\"FloridaNE\"\' /glade/work/ahijevyc/ADCIRC/perfect_cntl.ncl | tee -a cmd.$f.exe
            echo sbatch -n 1 -t 5 --mem=10900 -A P64000499 -J $f -p dav cmd.$f.exe \; sleep 5
        done
    done
done

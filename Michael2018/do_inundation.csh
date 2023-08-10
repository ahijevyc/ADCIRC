#!/bin/sh


# grep sbatch from output.

A=NMMM0021
stormname=Michael2018
#for desc in "OFCL.nws20" nws20.control ; do
for desc in ECMWF.0p125.nws20.bt.origmesh.scaled_vmax_times_one2ten.Knaff_Zehr_pmin.replace_r34r50r64 ; do
    for minus_tide in False ; do 
        for dryland in "MHHW"; do
        #for f in nws20.2017090812.EPS_14.27km3km WRF.2017090812.EPS_14.27km3km; do
            for f in nws20.control.2018100700 $desc.2018100800.PF?? $desc.2018100812.PF?? $desc.2018100900.PF?? $desc.2018100912.PF?? $desc.2018101000.PF?? ; do 
                echo "#!/bin/csh" > cmd.$f.exe
                echo module load ncl >> cmd.$f.exe
                echo setenv NCL_DEF_LIB_DIR /glade/u/home/ahijevyc/src/ncl_shared_objects/ | tee -a cmd.$f.exe
                echo ncl \'dryland=\"$dryland\"\' \'stormname=\"$stormname\"\' minus_astronomical_tide=$minus_tide \'modelstr=\"$f\"\' ymax=1.0 zoom=1 /glade/work/ahijevyc/ADCIRC/inundation_timeseries.ncl | tee -a cmd.$f.exe
                echo sbatch -n 1 -t 128 --mem=4900 -A $A -J $f -p dav cmd.$f.exe \; sleep 10
            done
        done
    done
done

# Are any subsetted netCDF files older than the full domain fort.63.nc? 
# If so, that is a problem. ADCIRC was rerun, but the subsetted netCDF file was not recreated afterwards. 
./isolder.sh

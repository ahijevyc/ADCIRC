#!/bin/sh

stormname=Michael2018
for minus_tide in False; do 
    for dryland in "MHHW"; do
        # include trailing slash
        echo "#!/bin/csh" > cmd.exe
        echo module load ncl >> cmd.exe
        echo setenv NCL_DEF_LIB_DIR /glade/u/home/ahijevyc/src/ncl_shared_objects/ | tee -a cmd.exe
        for f in $TMPDIR/nos/output/$stormname/bt/work/ /glade/scratch/ahijevyc/ECMWF/0p125/nws20/origmesh.scaled_vmax_times_one2ten.Knaff_Zehr_pmin.replace_r34r50r64/201810????/ens_??/; do
            echo ncl \'dryland=\"$dryland\"\' \'stormname=\"$stormname\"\' minus_astronomical_tide=$minus_tide \'modeldir=\"$f\"\' zoom=2 elevationlt=5 /glade/work/ahijevyc/ADCIRC/perfect_cntl.ncl >> cmd.exe
        done
        echo "chmod u+x cmd.exe; ./cmd.exe"
    done
done

#!/bin/sh

stormname=IRMA
for minus_tide in False ; do 
    for dryland in "MHHW"; do
        for cluster in 1 2 3 4 5 6 ; do
            mkdir -p WRF.2017090512.cluster${cluster}.27km3km
            echo ncl \'dryland=\"$dryland\"\' \'stormname=\"$stormname\"\' thresh=1 minus_astronomical_tide=$minus_tide cluster=$cluster \'modelstr=\"WRF.2017090512\"\'  tracks=False \'ensemble_str=\"EPS_\"\' \'cluster_start_time=\"2017090912\"\' ncluster=6 cluster_deg=3 zoom=4 /glade/work/ahijevyc/ADCIRC/ensemble_avg_plot.ncl
            echo ncl \'dryland=\"$dryland\"\' \'stormname=\"$stormname\"\' thresh=1 minus_astronomical_tide=$minus_tide cluster=$cluster \'modelstr=\"WRF.2017090812\"\'  tracks=False \'ensemble_str=\"EPS_\"\' \'cluster_start_time=\"2017090912\"\' ncluster=5 cluster_deg=3 zoom=4 /glade/work/ahijevyc/ADCIRC/ensemble_avg_plot.ncl
        done
    done
done

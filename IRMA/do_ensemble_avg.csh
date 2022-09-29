#!/bin/sh

stormname=IRMA
idate=2017090812
modelstr=ECMWF.0p125.$idate
modelstr=ECMWF.0p125.nws19.$idate
modelstr=ECMWF.0p125.nws19.90percentile.$idate
modelstr=WRF.$idate
mkdir -p $modelstr
for minus_tide in False ; do 
    for dryland in "MHHW"; do
        for thresh in 1 ; do
            echo ncl \'dryland=\"$dryland\"\' \'stormname=\"$stormname\"\' thresh=$thresh minus_astronomical_tide=$minus_tide \'modelstr=\"$modelstr\"\' tracks=False \'ensemble_str=\"EPS_[0-9C][0-9O].27km3km\"\' zoom=2 markers=True /glade/work/ahijevyc/ADCIRC/ensemble_avg_plot.ncl
            echo ncl \'dryland=\"$dryland\"\' \'stormname=\"$stormname\"\' thresh=$thresh minus_astronomical_tide=$minus_tide \'modelstr=\"$modelstr\"\' tracks=False \'ensemble_str=\"EPS_[0-9C][0-9O].27km3km\"\' zoom=3 markers=True /glade/work/ahijevyc/ADCIRC/ensemble_avg_plot.ncl
            #echo ncl \'dryland=\"$dryland\"\' \'stormname=\"$stormname\"\' thresh=$thresh minus_astronomical_tide=$minus_tide \'modelstr=\"$modelstr\"\' tracks=False \'ensemble_str=\"[PC]F[0-9]*\"\' zoom=2 /glade/work/ahijevyc/ADCIRC/ensemble_avg_plot.ncl
            #echo ncl \'dryland=\"$dryland\"\' \'stormname=\"$stormname\"\' thresh=$thresh minus_astronomical_tide=$minus_tide \'modelstr=\"$modelstr\"\' tracks=False \'ensemble_str=\"[PC]F[0-9]*\"\' zoom=3 /glade/work/ahijevyc/ADCIRC/ensemble_avg_plot.ncl
        done
    done
done

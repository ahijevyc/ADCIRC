#!/bin/sh

stormname=IRMA
for minus_tide in False ; do 
    for dryland in "MHHW"; do
        mkdir -p ECMWF.0p125.2017090812
        mkdir -p ECMWF.0p125.nws19.2017090812
        mkdir -p WRF.2017090812
        for thresh in 1 2 3; do
        #echo ncl \'dryland=\"$dryland\"\' \'stormname=\"$stormname\"\' thresh=$thresh minus_astronomical_tide=$minus_tide \'modelstr=\"WRF.2017090812\"\' tracks=False \'ensemble_str=\"EPS_[0-9][0-9].27km3km\"\' zoom=4 /glade/work/ahijevyc/ADCIRC/ensemble_avg_plot.ncl
        #echo ncl \'dryland=\"$dryland\"\' \'stormname=\"$stormname\"\' thresh=$thresh minus_astronomical_tide=$minus_tide \'modelstr=\"WRF.2017090812\"\' tracks=False \'ensemble_str=\"EPS_[0-9][0-9].27km3km\"\' zoom=6 /glade/work/ahijevyc/ADCIRC/ensemble_avg_plot.ncl
        #echo ncl \'dryland=\"$dryland\"\' \'stormname=\"$stormname\"\' thresh=$thresh minus_astronomical_tide=$minus_tide \'modelstr=\"ECMWF.0p125.2017090812\"\' tracks=False \'ensemble_str=\"[PC]F[0-9]*\"\' zoom=4 /glade/work/ahijevyc/ADCIRC/ensemble_avg_plot.ncl
        #echo ncl \'dryland=\"$dryland\"\' \'stormname=\"$stormname\"\' thresh=$thresh minus_astronomical_tide=$minus_tide \'modelstr=\"ECMWF.0p125.2017090812\"\' tracks=False \'ensemble_str=\"[PC]F[0-9]*\"\' zoom=6 /glade/work/ahijevyc/ADCIRC/ensemble_avg_plot.ncl
            echo ncl \'dryland=\"$dryland\"\' \'stormname=\"$stormname\"\' thresh=$thresh minus_astronomical_tide=$minus_tide \'modelstr=\"ECMWF.0p125.nws19.2017090812\"\' tracks=False \'ensemble_str=\"[PC]F[0-9]*\"\' zoom=4 /glade/work/ahijevyc/ADCIRC/ensemble_avg_plot.ncl
            echo ncl \'dryland=\"$dryland\"\' \'stormname=\"$stormname\"\' thresh=$thresh minus_astronomical_tide=$minus_tide \'modelstr=\"ECMWF.0p125.nws19.2017090812\"\' tracks=False \'ensemble_str=\"[PC]F[0-9]*\"\' zoom=6 /glade/work/ahijevyc/ADCIRC/ensemble_avg_plot.ncl
        done
    done
done

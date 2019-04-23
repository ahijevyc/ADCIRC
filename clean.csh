#!/bin/csh
set echo
rm maxvel.63
rm fort.68.nc
rm fort.67.nc
if ("$1"all != "all") then
    rm metis_graph.txt partmesh.txt
    rm fort.61.nc
    rm fort.63.nc
    rm fort.73.nc fort.74.nc
    rm PE*/fort.33
    rm PE*/fort.13
    rm PE*/fort.15
endif
rm max*63.nc min*63.nc
cp /glade/scratch/fossell/ADCIRC/IRMA/coldstart/fort.68.nc.6sep00z fort.67.nc

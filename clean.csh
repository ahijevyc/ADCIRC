#!/bin/csh

rm -v maxvel.63
rm -v fort.68.nc
rm -v fort.67.nc
if ("$1" != "") then
    rm -v metis_graph.txt partmesh.txt
    rm -v fort.61.nc
    rm -v fort.63.nc
    rm -v fort.73.nc fort.74.nc
    rm -v PE*/fort.33
    rm -v PE*/fort.13
    rm -v PE*/fort.15
endif
rm -v max*63.nc min*63.nc
# I think prep_adcirc_dir.csh does this
#cp /glade/scratch/fossell/ADCIRC/IRMA/coldstart/fort.68.nc.6sep00z fort.67.nc

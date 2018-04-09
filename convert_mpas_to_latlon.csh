#!/bin/csh


set convert_mpas=/glade/scratch/ahijevyc/convert_mpas/convert_mpas

cd /glade/scratch/mpasrt/uni

foreach f (2017090* 20170910*)
    cd $f/ecic/
    # Remove comment lines before saving to 'include_fields'
    egrep -v '^#' /glade/p/work/ahijevyc/tracking_gfdl/mpas_fields_to_interpolate.txt > include_fields
    # describe target domain
    echo "startlat = 5\nendlat=40\nstartlon=-100\nendlon=-40\nnlat=280\nnlon=480" > target_domain
    $convert_mpas init.nc diag*.nc
    break
end

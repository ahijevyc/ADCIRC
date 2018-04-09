#!/bin/env python

from netCDF4 import Dataset, num2date
import numpy as np
import glob,sys,datetime
import pdb

# Read u10 and v10 (or slp) from WRF/MPAS lat-lon files and create fort.222 - fort.224
#
"""
First interpolate to a destination lat-lon grid.

For WRF: 
    ncl /glade/p/work/ahijevyc/ncl/interpolateWRF.ncl
    Produces files like "wrfout_"+grid+"_????-??-??_??:??:??_latlon.nc"
For MPAS: 
    ~ahijevyc/bin_cheyenne/mpas_to_latlon
    Perhaps shave down the longitude range
    ncks -d lon,500,1200 diag.2017-09-07_00.00.00_0.125deg_000km.nc t.nc

This script produces fort.22x records.  The fort.22x file could be fort.221 or fort.222 or fort.223 or fort.224, depending on the arguments provided.
1st argument is the file. 2nd argument is "u" or "slp".

Here is the expected string of commands. You can copy and paste this:

# Main header required at top of fort.22x file.
echo "                                                       2017091000     2017091300" > fort.221
echo "                                                       2017091000     2017091300" > fort.222

foreach coarse_grid_file (diag*.nc)
    python /glade/p/work/ahijevyc/ADCIRC/make_fort.22x.py $coarse_grid_file slp >> fort.221
    python /glade/p/work/ahijevyc/ADCIRC/make_fort.22x.py $coarse_grid_file u >> fort.222
end

python /glade/p/work/ahijevyc/ADCIRC/make_fort.22x.py nested_grid_file slp >> fort.223 [optional]
python /glade/p/work/ahijevyc/ADCIRC/make_fort.22x.py nested_grid_file u >> fort.224 [optional]

where d01 is the big domain and d02 is the nested domain.

"""


# Formatting based on adcirc.org/home/documentation/users-manual-v51/input-file-descriptions/single-file-meteorological-forcing-input-fort-22/ accessed June 15, 2017 and Kate Fossell's experience

file = sys.argv[1]

# field 'slp' or 'u'
field = sys.argv[2]
if field not in ['u','slp']:
    print "bad field",field
    sys.exit(1)

# Print array in 8 columns.
# Sure there is a built-in function for this but I don't know it yet.
def print_ncols(a,n=80,fill=1013.,fmt="{:10.4f}"):
    # Replace nans with fill value.
    inds = np.where(np.isnan(a))
    a[inds] = fill
    # Print elements from west to east, and then from south to north.
    # I think that is what order='C' or row-major order does. This is the default.
    line = ""
    for i,x in enumerate(a.flatten(order='C')):
        line = line + fmt.format(x)
        if len(line) >= n:
            print line
            line = ""
    if line:
        print line


def get_stuff(file):
    if file == 'latlon.nc':
        print 'script cannot process latlon.nc yet (output from convert_mpas)'
        sys.exit(1)

    ncf = Dataset(file,"r")

    if hasattr(ncf, u'START_DATE'):
        start_date = getattr(ncf, u'START_DATE')
    if hasattr(ncf, u'config_start_time'):
        start_date = getattr(ncf, u'config_start_time')
    yyyymmddhh = start_date[0:4] + start_date[5:7] + start_date[8:10] + start_date[11:13]
    lon = ncf.variables['lon'][:]
    lat = ncf.variables['lat'][:]
    u10 = ncf.variables['u10'][:]
    v10 = ncf.variables['v10'][:]
    if hasattr(ncf, 'model') and ncf.model == "mpas":
        valid_time, = num2date(ncf.variables['time'][:],ncf.variables['time'].units)
        # Round up datetime to nearest second. Prevents datetime(2012,12,31,23,22,24,999998) from being 20121231232224. 
        dsec = np.round(valid_time.microsecond/1000000.)
        valid_time = valid_time + datetime.timedelta(seconds=dsec)
        slp = ncf.variables['mslp'][:]
    else:
        # valid time should use Time attribute instead of assuming hours since 1901-1-1
        valid_time = datetime.datetime(1901,1,1,0) + datetime.timedelta(hours=float(ncf.variables['Time'][:]))
        slp = ncf.variables['slp'][:]
    if np.max(slp) > 100000: # Convert Pa to hPa
        slp = slp/100.
    ncf.close()
    return yyyymmddhh, valid_time, lon, lat, u10, v10, slp

yyyymmddhh, valid_time, lon, lat, u10, v10, slp = get_stuff(file)

nlat = lat.size
nlon = lon.size
dx = lon[1] - lon[0]
dy = lat[1] - lat[0]

swlon = np.min(lon)
# Try making swlon between -180 and 180
if swlon >= 180:
    swlon = swlon - 360.
# RECORD HEADER
# Does Dt change? Documentation says it is the start time, but Kate says yes.
print '%5s%4d%6s%4d%3s%6.4f%3s%6.4f%6s%8.3f%6s%8.3f%3s%12s' % ("iLat=",nlat,"iLong=",nlon,"DX=",dx,"DY=",dy,"SWLat=",np.min(lat),"SWlon=",swlon,"Dt=",valid_time.strftime('%Y%m%d%H%M'))
if field == "u":
    print_ncols(u10,fill=0.,fmt="{:10.5f}")
    print_ncols(v10,fill=0.,fmt="{:10.5f}")
if field == "slp":
    print_ncols(slp,fill=1013.,fmt="{:10.4f}")

#!/bin/env python

from netCDF4 import Dataset
import numpy as np
import glob,sys,datetime
import pdb

# Read u10 and v10 (or slp) from WRF lat-lon files and create fort.222 - fort.224
#
"""
The 1st script interpolates to a destination lat-lon grid. Usage:
ncl /glade/p/work/ahijevyc/ncl/interpolateWRF.ncl


and the 2nd one outputs the fort.22x files.  The fort.22x file could be fort.221 or fort.222 or fort.223 or fort.224, depending on the arguments provided. 1st argument is the grid ("d01", "d02", or "d03"). 2nd argument is "u" or "slp".

Here is the expected string of commands:

python /glade/p/work/ahijevyc/ADCIRC/make_fort.22x.py d01 slp > fort.221
python /glade/p/work/ahijevyc/ADCIRC/make_fort.22x.py d01 u > fort.222
python /glade/p/work/ahijevyc/ADCIRC/make_fort.22x.py d02 slp > fort.223 [optional]
python /glade/p/work/ahijevyc/ADCIRC/make_fort.22x.py d02 u > fort.224 [optional]

where d01 is the big domain and d02 is the nested domain.

"""


# Formatting based on adcirc.org/home/documentation/users-manual-v51/input-file-descriptions/single-file-meteorological-forcing-input-fort-22/ accessed June 15, 2017 and Kate Fossell's experience

# Location of lat-lon files (created with /glade/p/work/ahijevyc/ncl/interpolateWRF.ncl)
idir = "/glade/scratch/ahijevyc/ADCIRC/IRMA/ncar_ensf/2017090800/ens_1/"

# Grid d02 or d03
grid = sys.argv[1]
if grid not in ['d01','d02','d03']:
    print "bad grid",grid
    sys.exit(1)

# field 'slp' or 'u'
field = sys.argv[2]
if field not in ['u','slp']:
    print "bad field",field
    sys.exit(1)

search_str= idir+"wrfout_"+grid+"_????-??-??_??:??:??_latlon.nc"
files = sorted(glob.glob(search_str))
if len(files) == 0:
    print "found", len(files), "files", search_str
    sys.exit(1)

# Print array in 8 columns.
# Sure there is a built-in function for this but I don't know it yet.
def print_ncols(a,n=80,fill=1013.,fmt="{:10.4f}"):
    # Replace nans with fill value.
    a = a.filled(fill)
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

ncf = Dataset(files[0],"r")
start_date = getattr(ncf, u'START_DATE')
yyyymmddhh = start_date[0:4] + start_date[5:7] + start_date[8:10] + start_date[11:13]
nlat = len(ncf.dimensions['lat'])
nlon = len(ncf.dimensions['lon'])
lon = ncf.variables['lon'][:]
lat = ncf.variables['lat'][:]
dx = lon[1] - lon[0]
dy = lat[1] - lat[0]
ncf.close()
# valid time should use Time attribute instead of assuming hours since 1901-1-1
# MAIN HEADER
print '%55s%10s%5s%10d' % ("",yyyymmddhh,"",2008091406)

for file in files:
    ncf = Dataset(file,"r")
    # Sanity check: make sure grid does not change
    if nlat != len(ncf.dimensions['lat']): sys.exit(1)
    if nlon != len(ncf.dimensions['lon']): sys.exit(1)
    lon = ncf.variables['lon'][:]
    lat = ncf.variables['lat'][:]
    if dx != lon[1] - lon[0] : sys.exit(1)
    if dy != lat[1] - lat[0] : sys.exit(1)
    u10 = ncf.variables['u10'][:]
    v10 = ncf.variables['v10'][:]
    slp = ncf.variables['slp'][:]
    valid_time = datetime.datetime(1901,1,1,0) + datetime.timedelta(hours=float(ncf.variables['Time'][:]))
    ncf.close()
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

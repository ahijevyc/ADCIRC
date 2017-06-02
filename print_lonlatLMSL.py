#!/bin/env python

# Print csv lon/lat/LMSL for Vdatum to convert to MHHW.

from netCDF4 import Dataset
ncf = Dataset("/glade/p/work/ahijevyc/ADCIRC/IKE/control/maxele.63.nc","r")
x = ncf.variables['x'][:]
y = ncf.variables['y'][:]
depth = ncf.variables['depth'][:]
ncf.close()


for lon,lat,d in zip(x,y,depth):
    # comma-separated numbers
    print ','.join(map(str, [lon, lat, -d]))

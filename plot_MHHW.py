#!/bin/env python
from mpl_toolkits.basemap import Basemap
import matplotlib.pyplot as plt
import os
from netCDF4 import Dataset
import numpy as np
import matplotlib.colors as colors
from matplotlib.mlab import bivariate_normal

# Plot LMSL for a subdomain and mark nodes where LMSL>=0 and MHHW<0.
# 
# Before running:
#   Use print_lonlatLMSL.py to create lonlatLMSL.csv
#   Convert ascii file LMSL to MHHW with ~/bin/vdatum.
#   Direct output to ./result/lonlatLMSL.csv (should be default)


ncfile = "lonlatLMSL.MHHW.nc"
msg = -999999.
if os.path.exists(ncfile):
    ncf = Dataset(ncfile,"r")
    lon = ncf.variables['lon'][:]
    lat = ncf.variables['lat'][:]
    mhhw = ncf.variables['mhhw'][:]
    x = ncf.variables['x'][:]
    y = ncf.variables['y'][:]
    lmsl = ncf.variables['lmsl'][:]
    ncf.close()
else:
    ifile = "lonlatLMSL.csv"
    lon,lat,mhhw = np.loadtxt("./result/"+ifile,delimiter=",",unpack=True)
    x,y,lmsl = np.loadtxt(ifile,delimiter=",",unpack=True)
    n = len(lon)
    ncf = Dataset(ncfile,"w")
    node = ncf.createDimension("node",n)
    lonv = ncf.createVariable("lon", "f4", ("node",))
    latv = ncf.createVariable("lat", "f4", ("node",))
    xv = ncf.createVariable("x", "f4", ("node",))
    yv = ncf.createVariable("y", "f4", ("node",))
    mhhwv = ncf.createVariable("mhhw", "f4", ("node",))
    lmslv = ncf.createVariable("lmsl", "f4", ("node",),fill_value=msg)
    lonv[:] = lon
    latv[:] = lat
    xv[:] = x 
    yv[:] = y 
    mhhwv[:] = mhhw 
    lmslv[:] = lmsl
    ncf.close()
m = Basemap(llcrnrlon=-98.,llcrnrlat=25.,urcrnrlon=-80.5,urcrnrlat=31.7, projection='merc', resolution ='h')

levels=[-5000,-2000,-1000,-500,-200,-100,-50,-20,-10,-5,-2,0,2,5,10,20]
CS = m.contourf(lon,lat,lmsl,latlon=True,tri=True,cmap=plt.cm.terrain,norm=colors.SymLogNorm(linthresh=5, linscale=5, vmin=-5000, vmax=20),levels=levels)
cbar = m.colorbar(CS,location='bottom',label='m',ticks=levels)
plt.title('LMSL')
water = lmsl < 0
beach = (lmsl >= 0) & (mhhw < 0) & (mhhw != msg)
#nodes = m.scatter(x,y,latlon=True,marker='.',s=0.5,label="nodes")
#waters = m.scatter(x[water],y[water],latlon=True,color='blue',marker='.',s=0.5,label="water")
beaches = m.scatter(x[beach],y[beach],latlon=True,marker='.',color='red',s=0.5,label="LMSL>=0, MHHW<0")
m.drawcoastlines()
m.drawmeridians(range(0, 360, 1),linewidth=0.5)
m.drawparallels(range(0, 90, 1),linewidth=0.5)

plt.legend() #[nodes,waters,beaches])
plt.show()



#!/usr/bin/env python

from netCDF4 import Dataset, chartostring
import numpy as np
import glob,sys,datetime,os
import pdb
import argparse

# Convert MPAS diagnostic files to ascii needed by ADCIRC NWS=16
# Replaces ".nc" with ".nws16"
# Make fort.22 file that refers to those ascii files.
#
# Read lat/lon from MPAS init.nc file (latCells and latCells)
# and read u10, v10, and slp from MPAS diagnostic file(s)
# and create fort.22 for ADCIRC input NWS = 16

"""
usage: mpas_fort.22.py [-h] [--latmin LATMIN] [--latmax LATMAX]
                       [--lonmin LONMIN] [--lonmax LONMAX] [-f]
                       initfile starth files [files ...]

init file and list of diagnostics files

positional arguments:
  initfile         initialization file init.nc with latCell and lonCell
  starth           hours to add to forecast time. hours since ADCIRC cold
                   start if nws>0. If nws<0, just keep as default 0.
  files            diagnostics file(s) with u10,v10,mslp,t2m

optional arguments:
  -h, --help       show this help message and exit
  --latmin LATMIN  minimum latitude (deg)
  --latmax LATMAX  maximum latitude (deg)
  --lonmin LONMIN  minimum longitude (deg) (-180 to 180)
  --lonmax LONMAX  maximum longitude (deg) (-180 to 180)
  -f, --force      force overwrite

"""


# Formatting based on http://adcirc.org/home/documentation/users-manual-v52/input-file-descriptions/meteorological-forcing-data-fort-22/ NWS = 16

parser = argparse.ArgumentParser(description="init file and list of diagnostics files")
parser.add_argument('initfile', type=str, help='initialization file init.nc with latCell and lonCell')
parser.add_argument('starth', type=float, default=0., help='hours to add to forecast time. hours since ADCIRC cold start if nws>0. If nws<0, just keep as default 0.')
parser.add_argument('files', type=str, nargs='+', help='diagnostics file(s) with u10,v10,mslp,t2m')
parser.add_argument('--latmin', type=float, default= -90., help='minimum latitude (deg)')
parser.add_argument('--latmax', type=float, default=  90., help='maximum latitude (deg)')
parser.add_argument('--lonmin', type=float, default=-180., help='minimum longitude (deg) (-180 to 180)')
parser.add_argument('--lonmax', type=float, default= 180., help='maximum longitude (deg) (-180 to 180)')
parser.add_argument('-f', '--force', action='store_true', help='force overwrite')
args = parser.parse_args()
files = args.files

ncf = Dataset(args.initfile,"r")
print "reading lat/lon/nCells from", args.initfile
lons = ncf.variables['lonCell'][:]
lons = np.degrees(lons) #convert from radians to degrees 
# make lon between -180 and 180 (subtract 360 from anything over 180)
lons[lons>=180] = lons[lons>=180] - 360
lats = ncf.variables['latCell'][:]
lats = np.degrees(lats) #convert from radians to degrees 
ncf.close
# Get indices of cells within lat/lon range
iCells = np.logical_and(np.logical_and(lats>=args.latmin,
                                       lats<=args.latmax),
                        np.logical_and(lons>=args.lonmin,
                                       lons<=args.lonmax))
nCells = np.sum(iCells) # Don't count False values by using len()
lats = lats[iCells]
lons = lons[iCells]

if len(files) == 0:
    print "found", len(files), "diagnostic files", search_str
    sys.exit(1)


f22 = open("fort.22", "w")
f22header = "! "+datetime.datetime.now().strftime("%c")+" initfile="+os.path.realpath(args.initfile)
f22header += " latmin,latmax,lonmin,lonmax="+"%8.3f,%8.3f,%9.3f,%9.3f"%(args.latmin,args.latmax,args.lonmin,args.lonmax)+" nCells="+'%d\n' % nCells
if len(f22header) > 1024:
    print "fort.22 header line over 1024 characters"
    sys.exit(1)

f22.write(f22header)
f22.write("1.0 ! 2nd line is a velocity magnitude multiplier\n")
f22.write("20000.0 ! 3rd line: maximum extrapolation distance (m)\n")


ramp_mult = 1.

for file in files:
    ofile = os.path.splitext(file)[0] + ".nws16"
 
    if not args.force and os.path.exists(ofile):
        print ofile,"exists already"
        continue

    print "reading", file
    ncf = Dataset(file,"r")
    # xtime has time dimension
	#  char xtime(Time, StrLen) ;
	#	xtime:long_name = "Model valid time" ;
    xtime = chartostring(ncf.variables['xtime'][:])[0].strip()
    xtime = datetime.datetime.strptime(xtime, '%Y-%m-%d_%H:%M:%S')

    # 	char initial_time(StrLen) ;
	#	initial_time:long_name = "Model initialization time" ;
    initial_time = str(chartostring(ncf.variables['initial_time'][:])).strip()
    initial_time = datetime.datetime.strptime(initial_time, '%Y-%m-%d_%H:%M:%S')
    hour = (xtime - initial_time).total_seconds()/3600
    hour_since_cold_start = hour + args.starth

    # Web page has "-1" as Pc (mb), but source code does not have this argurment.
    f22.write('%.3f %.4f "%s"\n' % (hour_since_cold_start, ramp_mult, os.path.realpath(ofile)))
    itime = 0
    # Read fields from diagnostics file
    u10   = ncf.variables['u10'][:]
    u10   = u10[itime,iCells]
    v10   = ncf.variables['v10'][:]
    v10   = v10[itime,iCells]
    slp   = ncf.variables['mslp'][:]
    slp   = slp[itime,iCells]/100 # Convert from Pa to hPa (mb)
    tmpK  = ncf.variables['t2m'][:]
    tmpK  = tmpK[itime,iCells]
    q     = ncf.variables['q2'][:]
    q     = q[itime,iCells]
    ws    = q/(1-q) # convert from specific humidity to mixing ratio.
    rain_cm = ncf.variables['rainc'][:] + ncf.variables['rainnc'][:]
    rain_cm = rain_cm[itime,iCells]/10 # convert from mm to cm
    ncf.close()

    print "writing", ofile
    ofh = open(ofile, "w")
    ofh.write("%d\n" % nCells)
    fmt = "%10.4f"
    nest = 0

    #   Each ASCII GFDL met file contains one or more nested grid data
    #   where the nested grids are allowed to change in time.  Coarse grid
    #   data is not stored where finer nest data is given.
    #   Format of the file:
    #   Line 1:  Number of grid cells (f10.4) NCELLS
    #   Lines 2-NCELLS+1:  Have nine columns of data formatted as 9f10.4
    #         1. u (m/sec)
    #         2. v (m/sec)
    #         3. Temperature  (K)
    #         4. mixing ratio(kg/kg)
    #         5. storm accum precipitation (cm)
    #         6. sea level pressure (hPa)
    #         7. longitude (decimal deg)
    #         8. latitude (decimal deg)
    #         9. hurricane hour

    for u,v,t,w,rn,p,lon,lat in zip(u10,v10,tmpK,ws,rain_cm,slp,lons,lats):
        #cols = (u,v,t,w,rain,p,lon,lat,hour,nest)
        cols = (u,v,t,w,rn,p,lon,lat,hour) # no nest column
        ofh.write(len(cols)*fmt % cols)
        ofh.write("\n")
    ofh.close()
    f22.flush() # write filename as soon as it is ready
f22.close()

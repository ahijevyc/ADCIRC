from netCDF4 import Dataset, num2date
import numpy as np
import glob,sys,datetime
import pdb

# Read u10 and v10 (or slp) from WRF/MPAS lat-lon files and create fort.222 - fort.224
#
# May 14, 2018 - added ability to convert multi-time ECMWF 

"""
First interpolate to a destination lat-lon grid.

For ECMWF:
    grib2 files are already on lat/lon grid.
    Just ncl_convert2nc
For WRF: 
    ncl /glade/work/ahijevyc/ncl/interpolateWRF.ncl
    Produces files like "wrfout_"+grid+"_????-??-??_??:??:??_latlon.nc"
For MPAS: 
    ~ahijevyc/bin_cheyenne/mpas_to_latlon
    Perhaps shave down the longitude range
    ncks -d lon,500,1200 diag.2017-09-07_00.00.00_0.125deg_000km.nc t.nc

This script produces fort.22x records.  The fort.22x file could be fort.221 or fort.222 or fort.223 or fort.224, depending on the arguments provided.
1st argument is the file. 2nd argument is "u" or "slp".

Here is the expected string of commands. You can copy and paste this:

# If you have a nested grid (below), change first line of fort.22 from "1" to "2".

# Main header required at top of fort.22x file.

echo "                                                       2017090600     2017091400" > fort.221
echo "                                                       2017090600     2017091400" > fort.222
echo "                                                       2017090600     2017091400" > fort.223
echo "                                                       2017090600     2017091400" > fort.224

foreach coarse_grid_file (E01/E01*d02*.nc)
    python /glade/work/ahijevyc/ADCIRC/make_fort.22x.py $coarse_grid_file slp >> fort.221
    python /glade/work/ahijevyc/ADCIRC/make_fort.22x.py $coarse_grid_file u >> fort.222
end

foreach nested_grid_file (E01/E01*d03*.nc)
    python /glade/work/ahijevyc/ADCIRC/make_fort.22x.py $nested_grid_file slp >> fort.223
    python /glade/work/ahijevyc/ADCIRC/make_fort.22x.py $nested_grid_file u >> fort.224
end

# where d01 is the big domain and d02 is the nested domain.

"""


# Formatting based on adcirc.org/home/documentation/users-manual-v51/input-file-descriptions/single-file-meteorological-forcing-input-fort-22/ accessed June 15, 2017 and Kate Fossell's experience

file = sys.argv[1]

# field 'slp' or 'u'
field = sys.argv[2]
if field not in ['u','slp']:
    print("bad field",field)
    sys.exit(1)

# Print array in 8 columns.
def print_ncols(x,ncol=8,fill=1013.,fmt="%10.4f"):
    # Replace nans with fill value.
    x = x.filled(fill_value=fill)
    if x.size % ncol == 0:
        # Use fast method if size of x array is multiple of ncol. 
        np.savetxt(sys.stdout, np.reshape(x, (-1,ncol), order='C'), fmt=fmt, delimiter='')
    else: 
        # Print elements from west to east, and then from south to north.
        # I think that is what order='C' or row-major order does. This is the default.
        line = ""
        for i,e in enumerate(x.flatten(order='C')):
            line = line + fmt.format(e)
            if i % ncol == ncol-1: # TODO: untested with new format string. Used to have curly brackets and no percentage sign: '{:10.4f}'
                print(line)
                line = ""
        if line:
            print(line)

def roll(x, lon):
    # roll array so longitudes start at dateline 
    pos, = np.where(lon == 180)
    axis = x.ndim - 1
    return np.roll(x,pos,axis=axis)

def get_stuff(ifile):
    if file == 'latlon.nc':
        print('script cannot process latlon.nc yet (output from convert_mpas)')
        sys.exit(1)

    ncf = Dataset(ifile,"r")

    start_date = None
    if hasattr(ncf, 'START_DATE'):
        start_date = getattr(ncf, 'START_DATE')
    if hasattr(ncf, 'config_start_time'):
        start_date = getattr(ncf, 'config_start_time')
    if 'west_east' in ncf.variables:
        lon = ncf.variables['west_east'][:]
    if 'south_north' in ncf.variables:
        lat = ncf.variables['south_north'][:]
    if 'lon' in ncf.variables:
        lon = ncf.variables['lon'][:]
        lat = ncf.variables['lat'][:]
    if 'u10' in ncf.variables:
        u10 = ncf.variables['u10'][:]
        v10 = ncf.variables['v10'][:]
    # Grib file ECMWF
    if "10u_P1_L103_GLL0" in ncf.variables:
        sdate = ncf.variables["10u_P1_L103_GLL0"].initial_time
        start_date = sdate[6:10]+"/"+sdate[0:5]+" "+sdate[12:14]
        u10 = ncf.variables['10u_P1_L103_GLL0'][:]
        v10 = ncf.variables['10v_P1_L103_GLL0'][:]
        slp = ncf.variables['msl_P1_L101_GLL0'][:]
        lon = ncf.variables['lon_0'][:]
        lat = ncf.variables['lat_0'][:]
        u10 = roll(u10,lon)
        v10 = roll(v10,lon)
        slp = roll(slp,lon)
        lon  = roll(lon,lon)# make sure you roll longitude last!
    # grib1 file ECMWF Linus Magnussen
    if "10U_GDS0_SFC" in ncf.variables:
        sdate = ncf.variables["10U_GDS0_SFC"].initial_time
        start_date = sdate[6:10]+"/"+sdate[0:5]+" "+sdate[12:14]
        u10 = ncf.variables['10U_GDS0_SFC'][:]
        v10 = ncf.variables['10V_GDS0_SFC'][:]
        slp = ncf.variables['MSL_GDS0_SFC'][:]
        lon = ncf.variables['g0_lon_2'][:]
        lat = ncf.variables['g0_lat_1'][:]
        # Even though the usual ECMWF grib file (above) goes through the roll() function
        # to shift the starting longitude to the dateline, the grib1 input from Linus Magnussen
        # doesn't seem to need this.

    if start_date is None:
        print(ncf.variables)
        print("did not get start_date from "+ifile)
        pdb.set_trace()


    yyyymmddhh = start_date[0:4] + start_date[5:7] + start_date[8:10] + start_date[11:13]
    if hasattr(ncf, 'model') and ncf.model == "mpas":
        valid_time, = num2date(ncf.variables['time'][:],ncf.variables['time'].units)
        # Round up datetime to nearest second. Prevents datetime(2012,12,31,23,22,24,999998) from being 20121231232224. 
        dsec = np.round(valid_time.microsecond/1000000.)
        valid_time = valid_time + datetime.timedelta(seconds=dsec)
        valid_times = [valid_time]
        slp = ncf.variables['mslp'][:]
    if 'slp' in ncf.variables and 'Time' in ncf.variables:
        # valid time should use Time attribute instead of assuming hours since 1901-1-1
        valid_time = datetime.datetime(1901,1,1,0) + datetime.timedelta(hours=float(ncf.variables['Time'][:]))
        valid_times = [valid_time]
        slp = ncf.variables['slp'][:]
    if 'forecast_time0' in ncf.variables:
        fhrs = ncf.variables['forecast_time0'][:]
        valid_times = [datetime.datetime.strptime(yyyymmddhh, '%Y%m%d%H') + datetime.timedelta(hours=int(x)) for x in fhrs]

    if np.ma.max(slp) > 100000: # Convert Pa to hPa
        slp = slp/100.
     
    ncf.close()

    # making lon between -180 and 180
    lon[lon >= 180] = lon[lon >= 180] - 360.

    if lat[1] - lat[0] < 0:
        # flip latitude dimension
        lat  = np.flip(lat, 0)
        u10 = np.flip(u10,1)
        v10 = np.flip(v10,1)
        slp = np.flip(slp,1)

    return yyyymmddhh, valid_times, lon, lat, u10, v10, slp

yyyymmddhh, valid_times, lon, lat, u10s, v10s, slps = get_stuff(file)

nlat = lat.size
nlon = lon.size
dx = lon[1] - lon[0]
dy = lat[1] - lat[0]

# RECORD HEADER
# Does Dt change? Documentation says it is the start time, but Kate says yes.
def f22xrec_header(nlat,nlon,dx,dy,lat,lon,valid_time):
    print('%5s%4d%6s%4d%3s%6.4f%3s%6.4f%6s%8.3f%6s%8.3f%3s%12s' % (
                "iLat=",nlat,"iLong=",nlon,
                "DX=",dx,"DY=",dy,
                "SWLat=",lat[0],"SWlon=",lon[0],
                "Dt=",valid_time.strftime('%Y%m%d%H%M')
            ))

# Come up with better way of dealing with input netCDF files that have just one time or
# lotza times. 

def do_print_ncols(field,u10,v10,slp):
    if field == "u":
        print_ncols(u10,fill=0.,fmt="%10.5f")
        print_ncols(v10,fill=0.,fmt="%10.5f")
    if field == "slp":
        print_ncols(slp,fill=1013.,fmt="%10.4f")

# Deal with time dimension
if len(valid_times) > 1:
    for valid_time, u10, v10, slp in zip(valid_times,u10s,v10s,slps):
        f22xrec_header(nlat,nlon,dx,dy,lat,lon,valid_time)
        do_print_ncols(field,u10,v10,slp)
else:
    f22xrec_header(nlat,nlon,dx,dy,lat,lon,valid_times[0])
    do_print_ncols(field,u10s,v10s,slps)

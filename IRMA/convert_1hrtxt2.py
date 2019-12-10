import pandas as pd
import numpy as np
import pdb
import datetime
import sys
import glob
import os
import atcf
"""
Convert Alex Kowaleski's TC tracks to ATCF

run in /glade/work/ahijevyc/ADCIRC/IRMA

usage: python convert_1hrtxt2.py WRF*27km3km
"""
dirs = sys.argv[1:]


for memberdir in dirs:
    if not os.path.isdir(memberdir):
        print(memberdir+ " is not a directory")
        sys.exit(1)
    print("memberdir: "+memberdir)
    i = memberdir.find("EPS")
    ens = memberdir[i+4:i+6]
    infile = memberdir+"/EPS"+ens+"_track1hr.txt"
    if not os.path.isfile(infile):
        print(infile+ ' not a file. skipping')
        continue
    idate = datetime.datetime.strptime(os.path.basename(memberdir)[0:14], 'WRF.%Y%m%d%H')
    # columns in input file
    names = ['valid_time', 'lat', 'lon', 'minp', 'vmax']
    # parse valid_time this way
    dateparse = lambda x: pd.datetime.strptime(x, '%Y-%m-%d_%H:%M:%S')
    try:
        df = pd.read_csv(infile, names=names, delim_whitespace=True, parse_dates=['valid_time'], date_parser=dateparse)
    except TypeError:
        names.insert(0,"format") # newer files have string "ATCF" at start of each row. Call it "format"
        df = pd.read_csv(infile, names=names, delim_whitespace=True, parse_dates=['valid_time'], date_parser=dateparse)
    first_date = df.valid_time.iloc[0]
    if first_date != idate:
        print("date in memberdir doesn't match first date in "+infile)
        print(idate, df.valid_date)
        sys.exit(1)
    # fill in atcf columns
    df['basin'] = 'AL'
    df['cy'] = "11"
    df['initial_time'] = idate
    df['technum'] = 3
    df['ty'] = 'XX'
    df['model'] = 'WF'+ens
    df['windcode'] = '   '
    df['rad'] = "34" # figureGendir.csh expects 34
    df['rad1'] = 0
    df['rad2'] = 0
    df['rad3'] = 0
    df['rad4'] = 0
    df['router'] = 0
    df['pouter'] = 0
    df['eye'] = np.NaN
    df['rmw'] = np.NaN
    df['gusts'] = np.NaN
    df['maxseas'] = np.NaN
    df['subregion'] = ''
    df['initials'] = 'X'
    df['dir'] = np.NaN
    df['speed'] = np.NaN
    df['stormname'] = 'IRMA'
    df['depth'] = 'X'
    df['seas'] = 0
    df['seascode'] = '   '
    df['seas1'] = 0
    df['seas2'] = 0
    df['seas3'] = 0
    df['seas4'] = 0
    df['subregion'] = ''
    df['userdefine1'] = ''
    df['userdata1'] = ''
    # create timedelta for forecast hour
    df['fhr'] = df.valid_time - df.initial_time
    # convert to hour and integer
    df.fhr = ( df.fhr / pd.Timedelta(hours=1)).astype(int)
    atcf.write(memberdir+'/fort.22', df)

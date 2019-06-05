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
        print memberdir, "is not a directory"
        sys.exit(1)
    print memberdir
    i = memberdir.find("EPS")
    ens = memberdir[i+4:i+6]
    infile = memberdir+"/EPS"+ens+"_track1hr.txt"
    if not os.path.isfile(infile):
        print infile, 'not a file. skipping'
        continue
    # columns in input file
    names = ['valid_time', 'lat', 'lon', 'minp', 'vmax']
    # parse valid_time this way
    dateparse = lambda x: pd.datetime.strptime(x, '%Y-%m-%d_%H:%M:%S')
    df = pd.read_csv(infile, names=names, delim_whitespace=True, parse_dates=['valid_time'], date_parser=dateparse)
    # fill in atcf columns
    df['basin'] = 'AL'
    df['cy'] = 11
    df['initial_time'] = datetime.datetime(2017,9,5,12)
    df['technum'] = '03'
    df['ty'] = 'XX'
    df['model'] = 'WF'+ens
    df['windcode'] = 'NEQ'
    df['rad'] = 34 # figureGendir.csh expects 34
    df['rad1'] = np.NaN
    df['rad2'] = np.NaN
    df['rad3'] = np.NaN
    df['rad4'] = np.NaN
    df['router'] = np.NaN
    df['pouter'] = np.NaN
    df['eye'] = np.NaN
    df['rmw'] = np.NaN
    df['gusts'] = np.NaN
    df['maxseas'] = np.NaN
    df['subregion'] = ''
    df['initials'] = ''
    df['dir'] = np.NaN
    df['speed'] = np.NaN
    df['stormname'] = 'IRMA'
    df['depth'] = ''
    df['seascode'] = 'NEQ'
    df['seas'] = np.NaN
    df['seas1'] = np.NaN
    df['seas2'] = np.NaN
    df['seas3'] = np.NaN
    df['seas4'] = np.NaN
    df['subregion'] = ' '
    df['userdefined'] = ' '
    df['userdata'] = ' '
    # create timedelta for forecast hour
    df['fhr'] = df.valid_time - df.initial_time
    # convert to hour and integer
    df.fhr = ( df.fhr / pd.Timedelta(hours=1)).astype(int)
    atcf.write(memberdir+'/fort.22', df)

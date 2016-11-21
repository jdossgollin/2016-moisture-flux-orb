from ecmwfapi import ECMWFDataServer
import os.path
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--outfile', nargs=1, help='the output file to save to')
parser.add_argument('--bound', type=float, nargs=4, help = 'NORTH/WEST/SOUTH/EAST')
parser.add_argument('--syear', type=int, nargs=1, help = 'Starting Year of Analysis')
parser.add_argument('--eyear', type=int, nargs=1, help = 'End Year of Analysis')
parser.add_argument('--grid', type=float, nargs=1, help = 'How big to make the grid')
args = parser.parse_args()

# convert the args to useful info
lonmin = args.bound[1]
lonmax = args.bound[3]
latmin = args.bound[2]
latmax = args.bound[0]
outfile = args.outfile[0]
syear = args.syear[0]
eyear = args.eyear[0]
grid = args.grid[0]

# load module
from ecmwfapi import ECMWFDataServer

# run
server = ECMWFDataServer()
server.retrieve({
    "class": "ei",
    "dataset": "interim",
    "date": "%d-01-01/to/%d-12-31" %(syear, eyear),
    "expver": "1",
    "grid": "%f/%f" %(grid, grid),
    "levtype": "sfc",
    "param": "71.162/72.162",
    "step": "0",
    "stream": "oper",
    "time": "00:00:00/06:00:00/12:00:00/18:00:00",
    "type": "an",
    "format": "netcdf", # delete this if for some reason you want GRIB...
    "area": "%f/%f/%f/%f" %(latmax,lonmin,latmin,lonmax), # NORTH/WEST/SOUTH/EAST
    "target": "%s" %(outfile) # can modify the path here
})

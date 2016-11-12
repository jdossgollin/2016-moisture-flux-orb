from ecmwfapi import ECMWFDataServer
import os.path

start_year = 1980
end_year = 2012

# the low and high dipole definitions
llonmin = -95
llonmax = -82.5
llatmin = 30
llatmax = 40
hlonmin = -75
hlonmax=-62.5
hlatmin=30
hlatmax=40

# DOWNLOAD THE LOW

file = "processed/dipole_low.nc"
if not os.path.isfile(file):
    server = ECMWFDataServer()
    server.retrieve({
        "class": "ei",
        "dataset": "interim",
        "date": "%s-01-01/to/%s-12-31" %(start_year, end_year), #
        "expver": "1",
        "grid": "2.5/2.5", # grid resolution
        "levelist": "850", # levels to download
        "levtype": "pl",
        "param": "129.128", # specifies the what to download (geopotential hgt)
        "step": "0",
        "stream": "oper",
        "time": "00:00:00/06:00:00/12:00:00/18:00:00", # Time of Days
        "type": "an",
        "format": "netcdf", # delete this if for some reason you want GRIB...
        "area": "%s/%s/%s/%s" %(llatmax,llonmin,llatmin,llonmax), # NORTH/WEST/SOUTH/EAST
        "target": "%s" %(file) # can modify the path here
    })


# DOWNLOAD THE HIGH

file = "processed/dipole_high.nc"
if not os.path.isfile(file):
    server = ECMWFDataServer()
    server.retrieve({
        "class": "ei",
        "dataset": "interim",
        "date": "%s-01-01/to/%s-12-31" %(start_year, end_year), #
        "expver": "1",
        "grid": "2.5/2.5", # grid resolution
        "levelist": "850", # levels to download
        "levtype": "pl",
        "param": "129.128", # specifies the what to download (geopotential hgt)
        "step": "0",
        "stream": "oper",
        "time": "00:00:00/06:00:00/12:00:00/18:00:00", # Time of Days
        "type": "an",
        "format": "netcdf", # delete this if for some reason you want GRIB...
        "area": "%s/%s/%s/%s" %(hlatmax, hlonmin, hlatmin, hlonmax), # NORTH/WEST/SOUTH/EAST
        "target": "%s" %(file) # can modify the path here
    })

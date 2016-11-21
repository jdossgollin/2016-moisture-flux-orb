# -------- Packages and Options -------

pacman::p_load(data.table, magrittr, lubridate, ncdf4, optparse)

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--infile", type="character", default="reanalysis/moisture.nc",
              help="Path to moisture .ncdf file [default %default]"),
  make_option("--outfile", type="character", default="processed/flux.rda",
              help="File to save to [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))

# -------- Begin Script -------

nc <- nc_open(opt$infile)
q_east <- ncvar_get(nc, varid = 'p71.162')
q_north <- ncvar_get(nc, varid = 'p72.162')
lats <- ncvar_get(nc, varid = 'latitude')
lons <- ncvar_get(nc, varid = 'longitude')
time <- ymd_h('1900-01-01 0') + hours(ncvar_get(nc, varid = 'time'))
nc_close(nc)

nlat <- length(lats)
nlon <- length(lons)

q_east_net <- apply(q_east, 3, mean)
q_north_net <- apply(q_north, 3, mean)
q_mean <- data.table(time = time, dq = q_east_net + q_north_net)

save(q_mean, file = opt$outfile)

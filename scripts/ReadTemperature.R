# -------- Packages and Options -------

pacman::p_load(data.table, magrittr, lubridate, ncdf4, optparse)

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--infile", type="character", default="reanalysis/temperature.nc",
              help="Path to moisture .ncdf file [default %default]"),
  make_option("--gmx_box", type="character", default="config/gmx_box.R",
              help="Path to moisture .ncdf file [default %default]"),
  make_option("--outfile", type="character", default="processed/temp.rda",
              help="File to save to [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))

# -------- Begin Script -------

source(opt$gmx_box)

nc <- nc_open(opt$infile)
lons <- nc$dim$longitude$vals
lats <- nc$dim$latitude$vals
times <- ymd_h('1900-01-01 0') + hours(nc$dim$time$val)

start_idx <- c(which.min(abs(lons - gmx$lon[1])), which.min(abs(lats - gmx$lat[2])), 1)
count_idx <- c(which.min(abs(lons - gmx$lon[2])) - start_idx[1] + 1, which.min(abs(lats - gmx$lat[1])) - start_idx[2] + 1, -1)
temp <- ncvar_get(nc, 't2m', start = start_idx, count = count_idx)
temp <- apply(temp, 3, mean)

temp <- data.table(time = times, t2m = temp)
nc_close(nc)

save(temp, file = opt$outfile)
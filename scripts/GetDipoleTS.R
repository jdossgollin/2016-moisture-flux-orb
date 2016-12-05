# -------- Packages and Options -------
pacman::p_load(data.table, magrittr, ncdf4, lubridate, optparse)
pacman::p_load_gh('jdossgollin/JamesR')

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--gphnc", type="character", default="reanalysis/gph.nc",
              help="The high dipole  [default %default]"),
  make_option("--outfile", type="character", default="processed/dipole_ts.rda",
              help="Name of .rda file to store dipole time series  [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))

# -------- Begin Script -------

dipole <- list(high_x = c(-75, -62.5), high_y = c(30, 40), low_x = c(-95, -82.5), low_y = c(30, 40))

# read the dipole info
nc <- nc_open(opt$gphnc)
lons <- nc$dim$longitude$vals
lats <- nc$dim$latitude$vals
levels <- nc$dim$level$vals
times <- ymd_h('1900-01-01 0') + hours(nc$dim$time$vals)

# low dipole
low_start <- c(which.min(abs(lons - dipole$low_x[1])), which.min(abs(lats - dipole$low_y[2])), which(levels == 850), 1)
low_count <- c(which.min(abs(lons - dipole$low_x[2])) - low_start[1] + 1, which.min(abs(lats - dipole$low_y[1])) - low_start[2] + 1, 1, -1)
low <- ncvar_get(nc, varid = 'z', start = low_start, count = low_count)
low <- apply(low, 3, mean)

# high dipole
high_start <- c(which.min(abs(lons - dipole$high_x[1])), which.min(abs(lats - dipole$high_y[2])), which(levels == 850), 1)
high_count <- c(which.min(abs(lons - dipole$high_x[2])) - high_start[1] + 1, which.min(abs(lats - dipole$high_y[1])) - high_start[2] + 1, 1, -1)
high <- ncvar_get(nc, varid = 'z', start = high_start, count = high_count)
high <- apply(high, 3, mean)

# Merge the Dipole, Convert to hPa
dipole <- data.table(date = times, dipole = (high - low) / 100)

save(dipole, file = opt$outfile)

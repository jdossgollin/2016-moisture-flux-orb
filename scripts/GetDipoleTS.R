# -------- Packages and Options -------

pacman::p_load(data.table, magrittr, ncdf4, lubridate, xts, optparse)
pacman::p_load_gh('jdossgollin/JamesR')

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--nchigh", type="character", default="processed/dipole_high.nc",
              help="The high dipole  [default %default]"),
  make_option("--nclow", type="character", default="processed/dipole_low.nc",
              help="The low dipole  [default %default]"),
  make_option("--outfile", type="character", default="processed/dipole_ts.rda",
              help="Name of .rda file to store dipole time series  [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))

# -------- Begin Script -------

# Low
nc <- nc_open(opt$nclow)
low <- ncvar_get(nc, 'z')
dates <- ncvar_get(nc, 'time')
nc_close(nc)
low <- apply(low, 3, mean)

# High
nc <- nc_open(opt$nchigh)
high <- ncvar_get(nc, 'z')
nc_close(nc)
high <- apply(high, 3, mean)

# Time: "hours since 1900-01-01 00:00:0.0"
dates <- ymd_h('1900-01-01 00', tz = "UTC") + hours(dates)

# Merge the Dipole, Convert to hPa
dipole <- as.xts((high - low) / 100, order.by = dates)

save(dipole, file = opt$outfile)

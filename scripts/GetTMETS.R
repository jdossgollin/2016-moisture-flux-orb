# -------- Packages and Options -------
pacman::p_load(data.table, magrittr, optparse, lubridate)

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--gridded", type="character", default="processed/tme_gridded.rda",
              help="Gridded TME [default %default]"),
  make_option("--latmin", type="integer", default="35",
              help="First year of data to collect [default %default]"),
  make_option("--latmax", type="integer", default="42.5",
              help="Last year of data to collect [default %default]"),
  make_option("--lonmin", type="integer", default="-90",
              help="First year of data to collect [default %default]"),
  make_option("--lonmax", type="integer", default="-77.5",
              help="Last year of data to collect [default %default]"),
  make_option("--outfile", type="character", default="processed/tme_ts.rda",
              help="Name of .rda file to store gridded tidy TME tracks  [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))

# -------- Function Definitions -------

load(opt$gridded)
gridded <- gridded[lon >= opt$lonmin & lon <= opt$lonmax & lat >= opt$latmin & lat <= opt$latmax]
gridded <- gridded[, .(dQ = sum(dQ)), by = date_time]

all_dates <- seq(gridded[, min(date_time)], gridded[, max(date_time)], 60*60*6) # by 6 hours
all_dates <- data.table(date_time = all_dates)
tme_ts <- merge(gridded, all_dates, by = 'date_time', all = T)
tme_ts[is.na(dQ), dQ := 0]

save(tme_ts, file = opt$outfile)

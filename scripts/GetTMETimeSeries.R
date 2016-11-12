# -------- Packages and Options -------
pacman::p_load(data.table, magrittr, optparse, lubridate, xts)

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--rawfile", type="character", default="processed/gridded_tmev2.rda",
              help="d [default %default]"),
  make_option("--latmin", type="integer", default="35",
              help="First year of data to collect [default %default]"),
  make_option("--latmax", type="integer", default="42.5",
              help="Last year of data to collect [default %default]"),
  make_option("--lonmin", type="integer", default="-90",
              help="First year of data to collect [default %default]"),
  make_option("--lonmax", type="integer", default="-77.5",
              help="Last year of data to collect [default %default]"),
  make_option("--outfile", type="character", default="processed/tme_ts.rda",
              help="Name of .rda file to store TME time series  [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))


# -------- Begin Script -------
load(opt$rawfile)

tme_ts <- gridded[lat >= opt$latmin & lat <= opt$latmax & lon >= opt$lonmin & lon <= opt$lonmax, 
                  .(dQ = sum(dQ)), by = date_time][order(date_time)]
all_datetime <- data.table(date_time = seq(tme_ts[, min(date_time)], tme_ts[, max(date_time)], by = 6 * 60 * 60))
tme_ts <- merge(tme_ts, all_datetime, by = 'date_time', all = T)
tme_ts[is.na(dQ), dQ := 0]

tme_ts <- as.xts(x = tme_ts$dQ, order.by = tme_ts$date_time)

save(tme_ts, file = opt$outfile)

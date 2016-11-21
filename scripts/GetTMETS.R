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
gridded <- gridded[, date := as_date(date_time)][, .(dQ = sum(dQ)), by = date]

all_dates <- data.table(date = seq(gridded[, min(date)], gridded[, max(date)], 1))
gridded <- merge(gridded, all_dates, by = 'date', all = T)
gridded[is.na(dQ), dQ := 0]

save(gridded, file = opt$outfile)

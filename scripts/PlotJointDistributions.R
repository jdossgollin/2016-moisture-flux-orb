# -------- Packages and Options -------
pacman::p_load(data.table, magrittr, lubridate, ggplot2, ggthemes, locfit, optparse)
pacman::p_load_gh('jdossgollin/JamesR')

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--flux", type="character", default="processed/moisture.rda",
              help="The file containing the TME data  [default %default]"),
  make_option("--tracks", type="character", default="processed/cyclone_tracks.rda",
              help="The file containing the cyclone tracks data  [default %default]"),
  make_option("--amo", type="character", default="processed/amo.rda",
              help="The file containing the AMO data  [default %default]"),
  make_option("--pna", type="character", default="processed/pna.rda",
              help="The file containing the PNA data  [default %default]"),
  make_option("--temp", type="character", default="processed/temp.rda",
              help="The file containing the temperature data  [default %default]"),
  make_option("--latmin", type="integer", default="35",
              help="First year of data to collect [default %default]"),
  make_option("--latmax", type="integer", default="42.5",
              help="Last year of data to collect [default %default]"),
  make_option("--lonmin", type="integer", default="-90",
              help="First year of data to collect [default %default]"),
  make_option("--lonmax", type="integer", default="-77.5",
              help="Last year of data to collect [default %default]"),
  make_option("--outpath", type="character", default="figs/moisture_cyclone_",
              help="Path and file beginning for output figures  [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))

# -------- Begin Script -------

load(opt$tracks)
load(opt$flux)

centroid <- c(mean(c(opt$lonmin, opt$lonmax)), opt$latmax)
dist_max <- 25
xl <- c(centroid[1] - dist_max - 5, centroid[1] + dist_max + 5)
yl <- c(centroid[2] - dist_max - 5, centroid[2] + dist_max + 5)
bsize <- 9

world <- map_data('world') %>% as.data.table()
setnames(world, 'long', 'lon')
world_rgn <- world[lon >= xl[1] & lon <= xl[2] & lat >= yl[1] & lat <= yl[2], unique(region)]
world <- world[region %in% world_rgn]

load(opt$tracks)
load(opt$flux)
load(opt$amo)
load(opt$pna)
load(opt$temp)

merged <- merge(temp, q_mean, by = 'time')
merged[, date := as_date(time)]
merged <- merge(merged, pna[, .(date, pna)], by = 'date')
merged[, ':='(year = year(date), month = month(date))]
merged <- merge(merged, amo[, .(year, month, amo)], by = c('month', 'year'))

merged[, .(t2m, dq, pna, amo)] %>% as.matrix() %>% pairs()

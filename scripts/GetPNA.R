# -------- Packages and Options -------

pacman::p_load(data.table, magrittr, ncdf4, lubridate, xts, optparse)
pacman::p_load_gh('jdossgollin/JamesR')

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--syear", type="integer", default="1979",
              help="First year of data to collect [default %default]"),
  make_option("--eyear", type="integer", default="2013",
              help="Last year of data to collect [default %default]"),
  make_option("--outfile", type="character", default="processed/pna.rda",
              help="Name of .rda file to store dipole time series  [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))

# -------- Begin Script -------

url <- 'http://iridl.ldeo.columbia.edu/SOURCES/.NOAA/.NCEP/.CPC/.Indices/.NHTI/.PNA/gridtable.tsv'
pna <- fread(url, skip = 1)
names(pna) <- c('t', 'pna')
pna[, date := ymd('1960-01-01') + months(floor(t))]
pna[, t := NULL]
pna[, ':='(month = month(date), year = year(date))]

pna <- pna[year >= opt$syear & year <= opt$eyear]

# re-order
pna <- pna[, .(date, year, month, pna)]

save(pna, file = opt$outfile)
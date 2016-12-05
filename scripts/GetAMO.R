# -------- Packages and Options -------
pacman::p_load(data.table, magrittr, lubridate, optparse)
pacman::p_load_gh('jdossgollin/JamesR')

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--syear", type="integer", default="1979",
              help="First year of data to collect [default %default]"),
  make_option("--eyear", type="integer", default="2013",
              help="Last year of data to collect [default %default]"),
  make_option("--outfile", type="character", default="processed/amo.rda",
              help="Name of .rda file to store dipole time series  [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))

# -------- Begin Script -------

url <- 'http://www.cpc.ncep.noaa.gov/products/precip/CWlink/pna/norm.nao.monthly.b5001.current.ascii'
amo <- fread(url)
names(amo) <- c('year', 'month', 'amo')
amo[, date := ymd(paste(year, month, '1'))]
amo <- amo[year >= opt$syear & year <= opt$eyear, .(year, month, date, amo)]
save(amo, file = opt$outfile)


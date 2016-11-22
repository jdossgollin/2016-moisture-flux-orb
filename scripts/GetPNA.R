# -------- Packages and Options -------

pacman::p_load(data.table, magrittr, ncdf4, lubridate, optparse)
pacman::p_load_gh('jdossgollin/JamesR')

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--syear", type="integer", default="1979",
              help="First year of data to collect [default %default]"),
  make_option("--eyear", type="integer", default="2013",
              help="Last year of data to collect [default %default]"),
  make_option("--lag", type="integer", default="20",
              help="Create a (n)-day running mean index of the PNA [default %default]"),
  make_option("--outfile", type="character", default="processed/pna.rda",
              help="Name of .rda file to store dipole time series  [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))

# -------- Begin Script -------

# this data set is very strange
url <- 'ftp://ftp.cpc.ncep.noaa.gov/cwlinks/norm.daily.pna.index.b500101.current.ascii'
tmpf <- tempfile()
download.file(url, destfile = tmpf)
tx  <- readLines(tmpf)
tx2  <- gsub(pattern = '*******', replace = " -999", x = tx, fixed = TRUE)
writeLines(tx2, con=tmpf)
pna <-  fread(tmpf, na.strings = '-999')
file.remove(tmpf)

names(pna) <- c('year', 'month', 'day', 'pna')
pna <- pna[year >= opt$syear & year <= opt$eyear]
pna[, date := ymd(paste(year, month, day))]
pna <- pna[, .(date, pna)]

# add a n-day lag term
pna[, pna_lag := stats::filter(pna, filter = rep(1 / opt$lag, opt$lag), sides = 1)]

save(pna, file = opt$outfile)

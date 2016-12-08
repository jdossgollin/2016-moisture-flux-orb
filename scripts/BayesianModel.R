# -------- Packages and Options -------
pacman::p_load(data.table, magrittr, lubridate, ggplot2, ggthemes, locfit, rstan, optparse)
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
  make_option("--dipole", type="character", default="processed/dipole_ts.rda",
              help="The file containing the temperature data  [default %default]"),
  make_option("--month1", type="integer", default="12",
              help="Months to include in study [default %default]"),
  make_option("--month2", type="integer", default="2",
              help="Months to include in study [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))
mkpdf <- F

# -------- Get the Data In Correct Format -------

load(opt$flux)
load(opt$tracks)
load(opt$amo)
load(opt$pna)
load(opt$temp)
load(opt$dipole)
source('functions/CycloneWeight.R')

# start with the 6-hour fields, then add slower- timescale fields
mrg <- merge(q_mean, temp, by = 'time')
setnames(dipole, 'date', 'time')
mrg <- merge(mrg, dipole, by = 'time')

# get the closest cyclone each day
cyclones[, weight := CycloneWeight(lon, lat, method = 'parallelogram')]
cyclones <- cyclones[, .SD[which.max(weight)], by = 'date_time']
mrg <- merge(mrg, cyclones[, .(time = date_time, weight)], by = 'time')

# bring in daily fields
mrg[, date := date(time)]
mrg <- merge(mrg, pna[, .(date, pna)], by = 'date')

# bring in monthly fields
mrg[, month := month(time)]
mrg[, year := year(time)]
mrg <- merge(mrg, amo[, .(year, month, amo)], by = c('year', 'month'))

# calculate running means
mrg[, high_persist := as.numeric(stats::filter(high, filter = rep(1/5, 5), sides = 1L))]

# subset the data
mrg <- mrg[month >= opt$month1 | month <= opt$month2] %>% na.omit()


# -------- Make Some Joint Distributional Plots Plots -------

if(mkpdf){
  png(file = 'figs/joint_distribution_everything.png', width = 2000, height = 2000)
  mrg[, .(dq, sst, low, high, pna, amo, high_persist)] %>%
    as.matrix() %>%
    pairs(pch = ".", 
          main = "DJF Pairwise Plots")
  dev.off()
}

# -------- Build a Model in Stan -------
rstan_options(auto_write = TRUE)
options(mc.cores = parallel::detectCores())

local_factors <- mrg[, .(weight, high)]
global_factors <- mrg[, .(pna)]
stan_data <- list(
  N = nrow(mrg),
  p = ncol(local_factors), k = ncol(global_factors),
  X = as.matrix(local_factors), Z = as.matrix(global_factors),
  y = mrg$dq
)
stan_fit <- stan(file = 'scripts/Model1.stan', data = stan_data, chains = 1)
print(stan_fit) 
traceplot(stan_fit) + theme_base(base_size = 10)
plot(stan_fit) + theme_base(base_size = 10)

# compare to OLS
ols <- lm(mrg$dq ~ as.matrix(local_factors))
summary(ols)

# generate some fake data
extract <- extract(stan_fit)

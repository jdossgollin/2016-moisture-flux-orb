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
              help="Months to include in study [default %default]"),
  make_option("--stanfile", type="character", default="bayesian/Model1.stan",
              help="The .stan model to run [default %default]"),
  make_option("--outpath", type="character", default="figs/bayesian_",
              help="Path to save figures [default %default]"),
  make_option("--outtext", type="character", default="bayesian/stan_out.txt",
              help="File to write the print.stanfit object to [default %default]")
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

# start with the 6-hour fields, degrade to daily, then add slower- timescale fields
mrg <- merge(q_mean, temp, by = 'time')
setnames(dipole, 'date', 'time')
mrg <- merge(mrg, dipole, by = 'time')
mrg[, date := as_date(time)]
mrg <- mrg[, lapply(.SD, mean), by = date, .SDcols = -'time']

# get the closest cyclone each day
cyclones[, date := as_date(date_time)]
cyclones[, weight := CycloneWeight(lon, lat, method = 'parallelogram')]
cyclones <- cyclones[, .SD[which.max(weight)], by = 'date']
mrg <- merge(mrg, cyclones[, .(date, weight)], by = 'date')

# bring in daily fields
mrg <- merge(mrg, pna[, .(date, pna)], by = 'date')

# bring in monthly fields
mrg[, month := month(date)]
mrg[, year := year(date)]
mrg <- merge(mrg, amo[, .(year, month, amo)], by = c('year', 'month'))

# calculate running means (5 days)
mrg[, high_persist := as.numeric(stats::filter(high, filter = rep(1/5, 5), sides = 1L))]

# subset the data -- this has to come after running means
mrg <- mrg[month >= opt$month1 | month <= opt$month2] %>% na.omit()

# -------- Make Some Joint Distributional Plots Plots -------

vars_plot <- c('dq', 'sst', 'low', 'high', 'dipole', 'weight', 'pna', 'amo', 'high_persist')
if(mkpdf){
  png(file = 'figs/joint_distribution_everything.png', width = 2000, height = 2000)
  mrg[, vars_plot, with = F] %>%
    as.matrix() %>%
    pairs(pch = ".",
          main = "DJF Pairwise Plots")
  dev.off()
  pdf(file = 'figs/marginal_distributions.pdf', width = 9, height = 9)
  par(mfrow = c(3, ceiling(length(vars_plot) / 3)))
  for(i in 1:length(vars_plot)) hist(mrg[, eval(parse(text = vars_plot[i]))], main = vars_plot[i])
  par(mfrow = c(1, 1))
  dev.off()
}

# -------- Build a Model in Stan -------

# stan options
rstan_options(auto_write = TRUE)
options(mc.cores = parallel::detectCores())

# for modeling -- subtract out the mean
mrg <- mrg[, vars_plot, with = F]

# rescale some of the parameters
JCenter <- function(x){x - mean(x)}
JRescale <- function(x){(x - mean(x)) / sd(x)}
mrg[, ':='(dq = dq / 10000, sst = JRescale(sst), low = JRescale(low), high = JRescale(high), dipole = JRescale(dipole), high_persist = JRescale(high_persist))]

# choose the variables to include in the model
local_factors <- mrg[, .(weight, high)]
global_factors <- mrg[, .(pna, amo, sst)]

# fit the model
stan_data <- list(
  N = nrow(mrg),
  p = ncol(local_factors), k = ncol(global_factors),
  X = as.matrix(local_factors), Z = as.matrix(global_factors),
  y = mrg$dq
)
stan_fit <- stan(file = opt$stanfile, data = stan_data, chains = 4)

# save to file
sink(file = opt$outtext); print(stan_fit); sink()

# make some plots
stan_caption <- paste0('The X variables: ', paste0(names(local_factors), collapse = ", "), '.   The Z variables: ', paste0(names(global_factors), collapse = ", "))
post_plot <-
  plot(stan_fit, pars = c('beta0', 'beta', 'sigma', 'alpha0', 'alpha', 'tau')) +
  geom_vline(xintercept = 0) +
  theme_base(base_size = 10) +
  labs(caption = stan_caption, title = "Posterior Parameter Distributions", x = "", y = "")
tplot <-
  traceplot(stan_fit) +
  theme_base(base_size = 10)  +
  labs(caption = stan_caption, title = "Chain Mixing in Posterior Simulations")

# quick model checking -- this is not full posterior model checking
post_plot %>% JamesR::EZPrint(fn = paste0(opt$outpath, 'posterior'), pdf = T, width = 8, height = 3.5)
tplot %>% JamesR::EZPrint(fn = paste0(opt$outpath, 'traceplot'), pdf = T, width = 10, height = 6)

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
  make_option("--nao", type="character", default="processed/nao.rda",
              help="The file containing the nao data  [default %default]"),
  make_option("--pna", type="character", default="processed/pna.rda",
              help="The file containing the PNA data  [default %default]"),
  make_option("--temp", type="character", default="processed/temp.rda",
              help="The file containing the temperature data  [default %default]"),
  make_option("--dipole", type="character", default="processed/dipole_ts.rda",
              help="The file containing the temperature data  [default %default]"),
  make_option("--locfit", type="character", default="processed/locfit_model.rda",
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
mkpdf <- T

# -------- Get the Data In Correct Format -------

load(opt$pna)
load(opt$flux)
load(opt$tracks)
load(opt$amo)
load(opt$nao)
load(opt$temp)
load(opt$dipole)

# start with the 6-hour fields, degrade to daily, then add slower- timescale fields
mrg <- merge(q_mean, temp, by = 'time')
setnames(dipole, 'date', 'time')
mrg <- merge(mrg, dipole, by = 'time')
mrg[, date := as_date(time)]
mrg <- mrg[, lapply(.SD, mean), by = date, .SDcols = -'time']

# get the closest cyclone each day
#cyclones[, date := as_date(date_time)]
#cyclones[, weight := GetWeight(lon, lat, model = locfit_model)]
#cyclones <- cyclones[, .SD[which.max(weight)], by = 'date']
#mrg <- merge(mrg, cyclones[, .(date, weight)], by = 'date')

# bring in daily fields
mrg <- merge(mrg, nao[, .(date, nao = nao_lag)], by = 'date')
mrg <- merge(mrg, pna[, .(date, pna = pna_lag)], by = 'date')

# bring in monthly fields
mrg[, month := month(date)]
mrg[, year := year(date)]
mrg <- merge(mrg, amo[, .(year, month, amo)], by = c('year', 'month'))

# calculate running means (5 days)
# mrg[, high_persist := as.numeric(stats::filter(high, filter = rep(1/5, 5), sides = 1L))]

# subset the data -- this has to come after running means
mrg <- mrg[month >= opt$month1 | month <= opt$month2] %>% na.omit()

# rescale some of the parameters
JCenter <- function(x){x - mean(x)}
JRescale <- function(x){(x - mean(x)) / sd(x)}
mrg[, ':='(dq = dq / 10000, sst = JRescale(sst - mean(sst)), high = JRescale(high), low = JRescale(low))]
mrg[, dq_adj := log(dq - min(dq))]

# -------- Make Some Joint Distributional Plots Plots -------

vars_plot <- c('dq', 'sst', 'high', 'low', 'nao', 'pna')
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

# choose the variables to include in the model
local_factors <- mrg[, .(high, low, sst)]
global_factors <- mrg[, .(pna, nao)]

# fit the model
stan_data <- list(
  N = nrow(mrg),
  p = ncol(local_factors), k = ncol(global_factors),
  X = as.matrix(local_factors), Z = as.matrix(global_factors),
  y = mrg$dq
)
stan_fit <- stan(file = opt$stanfile, data = stan_data)

# save to file
sink(file = opt$outtext); print(stan_fit); sink()

# make some plots
stan_caption <- paste0('The X variables: ', paste0(names(local_factors), collapse = ", "), '.   The Z variables: ', paste0(names(global_factors), collapse = ", "))
length_taus <- ncol(local_factors)
length_alpha <- ncol(local_factors) * ncol(global_factors) + ncol(local_factors)
length_sigma <- 1
length_betas <- ncol(local_factors) + 1
hline_vec <- c(length_taus, length_alpha, length_sigma) %>% cumsum()

post_plot <-
  plot(stan_fit, pars = c('beta0', 'beta', 'sigma', 'alpha0', 'alpha', 'tau')) +
  geom_vline(xintercept = 0) +
  theme_base(base_size = 10) +
  geom_hline(yintercept = hline_vec + 0.5, color = 'gray') +
  labs(caption = stan_caption, title = "Posterior Parameter Distributions", x = "", y = "")
tplot <-
  traceplot(stan_fit) +
  theme_base(base_size = 10)  +
  labs(caption = stan_caption, title = "Chain Mixing in Posterior Simulations")

# print
post_plot %>% JamesR::EZPrint(fn = paste0(opt$outpath, 'posterior'), pdf = T, width = 8, height = 5)
tplot %>% JamesR::EZPrint(fn = paste0(opt$outpath, 'traceplot'), pdf = T, width = 10, height = 6)



# -------- Build a Model w/o Intermediate Steps -------
stan_data2 <- list(
  N = nrow(mrg),
  k = ncol(global_factors),
  Z = as.matrix(global_factors),
  y = mrg$dq
)
stan_fit_alternate <- stan(file = 'bayesian/Model2.stan', data = stan_data2, chains = 1)
traceplot(stan_fit_alternate) + theme_base()
plot(stan_fit_alternate) + theme_base()

# -------- Simulate an Event from Both -------

full_extract <- extract(stan_fit)
reduced_extract <- extract(stan_fit_alternate)

nsim <- 2500
subset <- mrg[nao > quantile(nao, 0.5) & pna > quantile(pna, 0.5), .(pna, nao, dq)]
simulated <- subset[sample(1:nrow(subset), nsim, replace = T)]
y_true <- simulated[, dq]
Z_sim <- simulated[, .(pna, nao)]

# simulate from reduced model
reduced_y <- rep(NA, nsim)
for(i in 1:nsim){
  par_idx <- sample(1:length(reduced_extract$beta0), 1)
  beta0_i <- reduced_extract$beta0[par_idx]
  beta_i <- reduced_extract$beta[par_idx, ]
  sigma_i <- reduced_extract$sigma[par_idx]
  z_i <- Z_sim[i, .(pna, nao)] %>% as.matrix()
  reduced_y[i] <- rnorm(1, mean = beta0_i + beta_i * z_i, sd = sigma_i)
}

full_y <- rep(NA, nsim)  
for(i in 1:nsim){
  par_idx <- sample(1:length(reduced_extract$beta0), 1)
  beta0_i <- full_extract$beta0[par_idx]
  beta_i <- full_extract$beta[par_idx, ]
  sigma_i <- full_extract$sigma[par_idx]
  alpha0_i <- full_extract$alpha0[par_idx, ]
  alpha_i <- full_extract$alpha[par_idx, , ]
  tau_i <- full_extract$tau[par_idx, ]
  z_i <- Z_sim[i] %>% as.matrix()
  Xhat_i <- rnorm(length(alpha0_i), mean = alpha0_i + z_i %*% alpha_i, sd = tau_i)
  full_y[i] <- rnorm(1, mean = beta0_i + Xhat_i %*% beta_i, sd = sigma_i)
}

par(mfrow = c(1, 2))
plot(reduced_y, y_true, main = "Reduced"); abline(a=0, b = 1, col=4)
plot(full_y, y_true, main = "Full"); abline(a=0, b = 1, col=4)
par(mfrow = c(1,1))

lm(y_true ~ reduced_y) %>% summary()
lm(y_true ~ full_y) %>% summary()

par(mfrow = c(3, 1))
hist(y_true, breaks = seq(-5, 10, 0.5), main = "Observed")
hist(full_y, breaks = seq(-5, 10, 0.5), main = "Full")
hist(reduced_y, breaks = seq(-5, 10, 0.5), main = "Reduced")
par(mfrow = c(1,1))

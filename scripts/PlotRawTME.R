# -------- Packages and Options -------

pacman::p_load_gh('jdossgollin/JamesR')
pacman::p_load(data.table, magrittr, lubridate, ggplot2, ggthemes, optparse, xts)

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--tmets", type="character", default="processed/tme_ts.rda",
              help="TME time series [default %default]"),
  make_option("--moisture", type="character", default="processed/moisture.rda",
              help="Moisture flux time series [default %default]"),
  make_option("--dipole", type="character", default="processed/dipole_ts.rda",
              help="Dipole index time series [default %default]"),
  make_option("--pna", type="character", default="processed/pna.rda",
              help="PNA time series [default %default]"),
  make_option("--out_path", type="character", default="figs/tme_plot_",
              help="Beginning of file names [default %default]"),
  make_option("--pdf", type="logical", default=TRUE,
              help="Name of .rda file to store gridded tidy TME tracks  [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))

# -------- Begin Script -------

load(opt$tmets); setnames(gridded, 'dQ', 'TME')
load(opt$moisture); setnames(q_mean, 'dq', 'q_flux')
load(opt$dipole)
load(opt$pna)
dipole[, time := date][, date := as_date(time)]
dipole <- dipole[, .(dipole = mean(dipole)), by = date]
q_mean[, date := as_date(time)]
q_mean <- q_mean[, .(q_flux = mean(q_flux)), by = date]

merged <-merge(merge(pna, q_mean, by = 'date', all = T), merge(dipole, gridded, by = 'date', all = T), by = 'date', all = T)
drange <- dipole[, range(date)]
merged <- merged[date >= drange[1] & date <= drange[2]]
merged[is.na(TME), TME := 0]
pairs(merged[, -'date', with = F], pch = '.', col = scales::alpha(1, 0.25))

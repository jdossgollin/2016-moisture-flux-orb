# -------- Packages and Options -------

pacman::p_load_gh('jdossgollin/JamesR')
pacman::p_load(data.table, magrittr, lubridate, ggplot2, ggthemes, optparse, xts)

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--tmepath", type="character", default="processed/tmev2.rda",
              help="Path TME data [default %default]"),
  make_option("--gridpath", type="character", default="processed/gridded_tmev2.rda",
              help="Path to gridded data [default %default]"),
  make_option("--tspath", type="character", default="processed/tme_ts.rda",
              help="Path to TME time series [default %default]"),
  make_option("--out_path", type="character", default="figs/tme_plot_",
              help="Beginning of file names [default %default]"),
  make_option("--pdf", type="logical", default=TRUE,
              help="Name of .rda file to store gridded tidy TME tracks  [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))

# -------- Begin Script -------

load(opt$tmepath); load(opt$gridpath); load(opt$tspath)
world <- map_data('world') %>% as.data.table()
setnames(world, 'long', 'lon')

# PLOT SOME TME TRACKS
tracks_all <- tme[, unique(traj_id)]
tracks_random <- sample(tracks_all, 25)
plot_tracks <- 
  tme[traj_id %in% tracks_random] %>%
  ggplot(aes(x=lon, y = lat)) +
  geom_path(aes(group = traj_id, color = Q)) +
  geom_path(data = world, aes(group = group)) +
  scale_color_distiller(palette = "PuBu", direction = 1) +
  ylim(c(15, 70)) +
  xlim(c(-140, 0)) +
  theme_map(base_size = 9) +
  coord_quickmap()
plot_tracks %>% EZPrint(fn = paste0(opt$out_path, 'all_seasons'), screen = !opt$pdf, pdf = opt$pdf, width = 8, height = 5)

# PLOT GRIDS
mean_grid <- gridded[, .(dQ = sum(dQ)), by = .(lon, lat)]
plot_grid <- 
  mean_grid %>%
  ggplot(aes(x= lon, y = lat)) + 
  geom_raster(aes(fill = dQ))  +
  geom_path(data = world, aes(group = group)) +
  scale_fill_gradient2() +
  ylim(c(15, 70)) +
  xlim(c(-140, 0)) +
  theme_map() +
  coord_quickmap()
plot_grid %>% EZPrint(fn = paste0(opt$out_path, 'gridded'), screen = !opt$pdf, pdf = opt$pdf, width = 8, height = 5)

# Plot Time Series
if(opt$pdf) pdf(file = paste0(opt$out_path, 'time series.pdf'), width = 9, height = 6)
plot(tme_ts, main = "Net TME into ORB", ylab = "Net TME Flux")
if(opt$pdf) dev.off()

# Tracks by Season
tracks_random2 <- sample(tracks_all, 200)
sub_tme <- tme[traj_id %in% tracks_random2]
sub_tme[, season := JamesR::GetSeasonDate(start_date)]
plot_tracks_season <- 
  sub_tme %>%
  ggplot(aes(x=lon, y = lat)) +
  geom_path(aes(group = traj_id, color = Q)) +
  geom_path(data = world, aes(group = group)) +
  scale_color_distiller(palette = "PuBu", direction = 1) +
  ylim(c(15, 70)) +
  xlim(c(-140, 0)) +
  theme_map() +
  coord_quickmap() +
  facet_wrap('season') +
  theme(legend.position = "bottom")
plot_tracks_season %>% EZPrint(fn = paste0(opt$out_path, 'track_by_season'), screen = !opt$pdf, pdf = opt$pdf, width = 12, height = 9)

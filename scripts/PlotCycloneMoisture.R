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
  make_option("--outpath", type="character", default="figs/moisture_cyclone_",
              help="Path and file beginning for output figures  [default %default]"),
  make_option("--latmin", type="integer", default="35",
              help="First year of data to collect [default %default]"),
  make_option("--latmax", type="integer", default="42.5",
              help="Last year of data to collect [default %default]"),
  make_option("--lonmin", type="integer", default="-90",
              help="First year of data to collect [default %default]"),
  make_option("--lonmax", type="integer", default="-77.5",
              help="Last year of data to collect [default %default]"),
  make_option("--month1", type="integer", default="12",
              help="Months to include in study [default %default]"),
  make_option("--month2", type="integer", default="3",
              help="Months to include in study [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))

# -------- Begin Script -------

centroid <- c(mean(c(opt$lonmin, opt$lonmax)), opt$latmax)
dist_max <- 25
xl <- c(centroid[1] - dist_max - 5, centroid[1] + dist_max + 5)
yl <- c(centroid[2] - dist_max - 5, centroid[2] + dist_max + 5)
bsize <- 9

load(opt$tracks)
load(opt$flux)

# Subset the raw data
cyclones[, month := month(date_time)] # THIS IS OPEN FOR DISCUSSION
cyclones <- cyclones[month >= opt$month1 | month <= opt$month2]
q_mean <- q_mean[month(time) >= opt$month1 | month(time) <= opt$month2]

world <- map_data('world') %>% as.data.table()
setnames(world, 'long', 'lon')
world_rgn <- world[lon >= xl[1] & lon <= xl[2] & lat >= yl[1] & lat <= yl[2], unique(region)]
world <- world[region %in% world_rgn]

# Associate the Tracks & Moisture Flux Time Series
setnames(cyclones, 'date_time', 'time')
tracks <- merge(cyclones, q_mean, by = 'time')
tracks[, centroid_distance := sqrt((lon - centroid[1])^2 + (lat - centroid[2])^2)]
tracks[, centroid_angle := atan2(lat - centroid[2], lon - centroid[1])]

# Plot
plt_track_moisture <-
  ggplot(tracks[centroid_distance < dist_max], aes(x = lon, y = lat)) +
  geom_polygon(data = world, aes(group = group), color = 'gray', fill = 'gray', alpha = 0.5) +
  geom_point(aes(color = dq), size = 0.5) +
  scale_color_gradient2() +
  geom_rect(aes(xmin = opt$lonmin, xmax = opt$lonmax, ymin = opt$latmin, ymax = opt$latmax), fill = NA, color =  'black') +
  coord_quickmap(xlim = xl, ylim = yl) +
  theme_map(base_size = bsize) +
  theme(legend.position = "bottom")
plt_track_moisture %>% JamesR::EZPrint(fn = paste0(opt$outpath, 'dq_given_locn'), pdf = T, width = 8, height = 10)

# Locfit
data_locfit <- tracks[centroid_distance < dist_max]
lf <- locfit(dq ~ ang(centroid_angle), data = data_locfit)
crit(lf) <- crit(lf, cov = 0.95)
pdf(file = paste0(opt$outpath, 'locfit.pdf'), width = 8, height = 4)
plot(lf, band = "local", xlab = "Centroid Angle", ylab = "Expected Moisture Flux", main = "Centroid Angle Modulation of Moisture Flux")
dev.off()

# equivalent plot w/ a LOESS smooth
plt_angle <-
  ggplot(data_locfit, aes(x = centroid_angle %% (2*pi), y = dq)) +
  geom_point(size = 0.1, alpha = 0.1) +
  theme_minimal(base_size = bsize) +
  facet_wrap('season') +
  labs(x = "Centroid Angle Relative to Box Centroid", y = "Moisture Flux",
       title = "Positional Modulation of Moisture Flux") +
  scale_x_continuous(breaks = pi * seq(0, 2, 0.5), labels = function(x){paste0(x/pi, ' pi')})
plt_angle %>% JamesR::EZPrint(fn = paste0(opt$outpath, 'dq_given_angle'), pdf = T, width = 7, height = 4)

# propreties of each cyclone
by_cyclone <- data_locfit[order(stormnum)][, .(dq_max = max(dq)), by = .(stormnum, season)]

# strongest cyclones & equal bootstrap sample
by_cyclone[, rank := rank(-dq_max, ties.method = "random"), by = season]
strong_cyclone_idx <- by_cyclone[rank <= 100, stormnum]
strong_cyclones <-  tracks[stormnum %in% strong_cyclone_idx]
by_cyclone[, r_idx := sample(1:.N), by = season]
random_cyclone_idx <- by_cyclone[r_idx <= 100, stormnum]
random_cyclones <- tracks[stormnum %in% random_cyclone_idx]
strong_cyclones[, type := 'High Flux']
random_cyclones[, type := 'Bootstrap']

# plot tracks of random & strong cylones
plt_track_conditional <-
  ggplot(rbind(strong_cyclones, random_cyclones), aes(x = lon, y = lat)) +
  geom_polygon(data = world, aes(group = group), color = 'gray', fill = 'gray', alpha = 0.5) +
  geom_path(aes(group = stormnum, color = intensity)) +
  facet_wrap('type') +
  scale_color_distiller(palette = "YlOrRd", direction = 1) +
  geom_rect(aes(xmin = opt$lonmin, xmax = opt$lonmax, ymin = opt$latmin, ymax = opt$latmax), fill = NA, color =  'black') +
  theme_map(base_size = bsize) +
  coord_quickmap(xlim = xl, ylim = yl) +
  theme(legend.position = "bottom")
plt_track_conditional %>% JamesR::EZPrint(fn = paste0(opt$outpath, 'tracks_given_flux'), pdf = T, width = 12, height = 7)
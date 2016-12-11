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
bsize <- 11

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

# adjust the units of the DQ
normalizing_factor = 1e4
tracks[, dq := dq / normalizing_factor]

# a really simple but useful one
pdf(file = paste0(opt$outpath, 'q_distribution.pdf'), width = 6, height = 3.5)
q_mean[, month := month(time)][month >= opt$month1 | month <= opt$month2, dq / normalizing_factor] %>% 
  hist(xlab = paste0("Net Moisture Flux (", normalizing_factor, " kg/m/s)"), ylab = "", yaxt = "n",
       main = "Moisture Flux into Ohio River Basin")
dev.off()

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
plt_track_moisture %>% JamesR::EZPrint(fn = paste0(opt$outpath, 'dq_given_locn'), pdf = T, width = 6, height = 7.5)

# propreties of each cyclone
by_cyclone <- tracks[centroid_distance <= dist_max][order(stormnum)][, .(dq_max = max(dq)), by = .(stormnum, season)]

# strongest cyclones & equal bootstrap sample
by_cyclone[, rank := rank(-dq_max, ties.method = "random"), by = season]
strong_cyclone_idx <- by_cyclone[rank <= 70, stormnum]
strong_cyclones <-  tracks[stormnum %in% strong_cyclone_idx]
by_cyclone[, r_idx := sample(1:.N), by = season]
random_cyclone_idx <- by_cyclone[r_idx <= 70, stormnum]
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
  theme_bw(base_size = bsize) +
  theme(panel.grid = element_line(color = 'black'), legend.position = "bottom") +
  labs(x = "", y = "") +
  coord_map("albers", lat0 = 25, lat1 = 45, xlim = c(-120, -40), ylim = c(20, 70))
plt_track_conditional %>% JamesR::EZPrint(fn = paste0(opt$outpath, 'tracks_given_flux'), pdf = T, width = 10, height = 5.5)

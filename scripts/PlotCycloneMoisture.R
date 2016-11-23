# -------- Packages and Options -------
pacman::p_load(data.table, magrittr, lubridate, ggplot2, ggthemes, optparse)
pacman::p_load_gh('jdossgollin/JamesR')

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--flux", type="character", default="processed/flux.rda",
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
              help="Last year of data to collect [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))

# -------- Begin Script -------

load(opt$tracks)
setnames(cyclones, 'Intensity', 'intensity')
setnames(cyclones, 'date', 'time')
setkey(cyclones, stormnum, date0)

load(opt$flux)

world <- map_data('world') %>% as.data.table()
setnames(world, 'long', 'lon')

yl <- c(20, 65); xl <- c(-150, -50)

# keep north american cyclones only
cyclones <- cyclones[lon >= xl[1] & lon <= xl[2] & lat >= yl[1] & lat <= yl[2]]

setkey(q_mean, dq)
q_mean[, quantile_moisture := order(dq) / .N]
mrg <- merge(q_mean, cyclones, by = 'time')
mrg[, idx := .I]

# pressure extremes
mrg_xtr <- rbind(
  mrg[quantile_moisture >= 0.99][, category := 'High Moisture Flux'],
  mrg[quantile_moisture <= 0.01][, category := 'Low Moisture Flux']
)
mrg_xtr[, category := as.factor(category)]
mrg_xtr[, centerpr := centerpr / 10^3]

plt_xtr <-
  mrg_xtr %>%
  ggplot(aes(x = lon, y = lat)) + 
  geom_polygon(data = world[lon >= xl[1] & lon <= xl[2] & lat >= yl[1] & lat <= yl[2]], aes(group = group), color = "gray", fill = "gray", alpha = 0.5) +
  geom_point(aes(color = centerpr), alpha = 0.75, size = 1) +
  geom_rect(aes(xmin = opt$lonmin, xmax = opt$lonmax, ymin = opt$latmin, ymax = opt$latmax), fill = NA, color =  'black') +
  facet_grid(category ~ season) +
  xlim(xl) + ylim(yl) +
  coord_quickmap() + 
  theme_map() +
  scale_color_distiller(palette = "YlOrRd") +
  theme(legend.position = "bottom", legend.key.width = unit(0.5, "in")) +
  labs(title = "Cyclone Centers on Dates with High/Low Moisture Flux to ORB",
       color = "Cyclone Center Pressure (kPa)")
plt_xtr %>% JamesR::EZPrint(fn = paste0(opt$outpath, 'xtr_flux'), pdf = T, width = 10, height = 4)

# tracks
low_flux_idx <- mrg_xtr[category == 'Low Moisture Flux', unique(stormnum)]
high_flux_idx <- mrg_xtr[category == 'High Moisture Flux', unique(stormnum)]
cyclone_db <- mrg[, .(low = stormnum %in% low_flux_idx, high = stormnum %in% high_flux_idx), by = stormnum]
cyclone_xtr <- merge(mrg, cyclone_db[low == TRUE | high == TRUE], by = 'stormnum')
cyclone_xtr[, category := ifelse(low, 'Low Moisture Flux', 'High Moisture Flux')]

cyclone_xtr %>% 
  ggplot(aes(x = lon, y = lat)) +
  geom_polygon(data = world[lon >= xl[1] & lon <= xl[2] & lat >= yl[1] & lat <= yl[2]], aes(group = group), color = "gray", fill = "gray", alpha = 0.5) +
  geom_path(aes(group = stormnum, color = centerpr)) +
  geom_rect(aes(xmin = opt$lonmin, xmax = opt$lonmax, ymin = opt$latmin, ymax = opt$latmax), fill = NA, color =  'black') +
  xlim(xl) + ylim(yl) +
  coord_quickmap() + 
  theme_map() +
  facet_grid(category ~ season) +
  theme(legend.position = "bottom", legend.key.width = unit(0.5, "in")) +
  labs(title = "Cyclone Tracks Leading to High/Low Moisture Flux to ORB",
       color = "Cyclone Center Pressure (kPa)")

# THIS IS DEFINITELY GOOD FOR PART A OF THE FINDING
# need to (a) connect to PNA
# (b) get more rigorous method for assigning associated flux to each cyclone

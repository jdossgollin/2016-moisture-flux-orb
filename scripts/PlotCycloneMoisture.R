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

world <- map_data('world') %>% as.data.table()
setnames(world, 'long', 'lon')
yl <- c(20, 65)
xl <- c(-170, -40)

# get north american cyclones that are strong only
load(opt$tracks)
cyclones <- cyclones[lon >= xl[1] & lon <= xl[2] & lat >= yl[1] & lat <= yl[2]]
cyclones[, intensity := log(-intensity)]
cyclones <- cyclones[intensity >= 6.5]
cyclones[, centerpr := centerpr / 10^3] # kPa
cyclones <- unique(cyclones)
cyclones[, stormnum := .GRP, by = .(lon0, lat0, init_dt)]

cyclone_ts <- cyclones[, .(n = .N), by = date_time]
cyclone_ts_dtime <- cyclone_ts[n == max(cyclone_ts$n)][1, date_time]
cyclones[date_time == cyclone_ts_dtime] %>%
  ggplot(aes(x = lon, y = lat)) + 
  geom_polygon(data = world[lon >= xl[1] & lon <= xl[2] & lat >= yl[1] & lat <= yl[2]], aes(group = group), color = "gray", fill = "gray", alpha = 0.5) +
  geom_point(aes(color = intensity), alpha = 0.75, size = 1)

# get moisture flux data
load(opt$flux)
setkey(q_mean, dq)
q_mean[, quantile_moisture := order(dq) / .N]
setnames(q_mean, 'time', 'date_time') # for compatability

# merge them together
mrg <- merge(q_mean, cyclones, by = 'date_time')

# pressure extremes
mrg_xtr <- rbind(
  mrg[quantile_moisture >= 0.975][, category := 'High Moisture Flux'],
  mrg[quantile_moisture <= 0.025][, category := 'Low Moisture Flux']
)
mrg_xtr[, category := as.factor(category)]

plt_xtr <-
  mrg_xtr %>%
  ggplot(aes(x = lon, y = lat)) + 
  geom_polygon(data = world[lon >= xl[1] & lon <= xl[2] & lat >= yl[1] & lat <= yl[2]], aes(group = group), color = "gray", fill = "gray", alpha = 0.5) +
  geom_point(aes(color = intensity), alpha = 0.75, size = 1) +
  geom_rect(aes(xmin = opt$lonmin, xmax = opt$lonmax, ymin = opt$latmin, ymax = opt$latmax), fill = NA, color =  'black') +
  facet_grid(category ~ season) +
  xlim(xl) + ylim(yl) +
  coord_quickmap() + 
  theme_map() +
  scale_color_distiller(palette = "YlOrRd", direction = 1) +
  theme(legend.position = "bottom", legend.key.width = unit(0.5, "in")) +
  labs(title = "Cyclone Centers on Dates with High/Low Moisture Flux to ORB",
       color = "Cyclone Intensity")
plt_xtr %>% JamesR::EZPrint(fn = paste0(opt$outpath, 'xtr_flux'), pdf = T, width = 15, height = 5)

# tracks associated with 
centroid <- c(mean(c(opt$lonmin, opt$lonmax)), mean(c(opt$latmin, opt$latmax)))
low_flux_idx <- mrg_xtr[sqrt((lon - centroid[1])^2 + (lat - centroid[2])^2) <= 20][category == 'Low Moisture Flux', unique(stormnum)]
high_flux_idx <- mrg_xtr[sqrt((lon - centroid[1])^2 + (lat - centroid[2])^2) <= 20][category == 'High Moisture Flux', unique(stormnum)]
cyclone_db <- mrg[, .(low = stormnum %in% low_flux_idx, high = stormnum %in% high_flux_idx), by = stormnum]
cyclone_xtr <- merge(mrg, cyclone_db[low == TRUE | high == TRUE], by = 'stormnum')
cyclone_xtr[, category := ifelse(low, 'Low Moisture Flux', 'High Moisture Flux')]

plt_tracks <- 
  cyclone_xtr %>% 
  ggplot(aes(x = lon, y = lat)) +
  geom_polygon(data = world[lon >= xl[1] & lon <= xl[2] & lat >= yl[1] & lat <= yl[2]], aes(group = group), color = "gray", fill = "gray", alpha = 0.5) +
  geom_path(aes(group = stormnum, color = intensity)) +
  geom_rect(aes(xmin = opt$lonmin, xmax = opt$lonmax, ymin = opt$latmin, ymax = opt$latmax), fill = NA, color =  'black') +
  xlim(xl) + ylim(yl) +
  scale_color_distiller(palette = "YlOrRd", direction = 1) +
  coord_quickmap() + 
  theme_map() +
  facet_grid(category ~ season) +
  theme(legend.position = "bottom", legend.key.width = unit(0.5, "in")) +
  labs(title = "Cyclone Tracks Leading to High/Low Moisture Flux to ORB",
       color = "Cyclone Intensity",
       caption = "Tracks within 20 degrees of box centroid at time of intense +/- flux anomaly (ignoring season)")
plt_tracks %>% JamesR::EZPrint(fn = paste0(opt$outpath, 'track'), pdf = T, width = 16, height = 5)

# THIS IS DEFINITELY GOOD FOR PART A OF THE FINDING
# need to (a) connect to PNA
# (b) get more rigorous method for assigning associated flux to each cyclone


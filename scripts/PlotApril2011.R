# -------- Packages and Options -------
pacman::p_load(RNCEP, data.table, magrittr, lubridate, ggplot2, ggthemes, locfit, rstan, optparse, ggmap)
pacman::p_load_gh('jdossgollin/JamesR')

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--flux", type="character", default="processed/moisture.rda",
              help="The file containing the TME data  [default %default]"),
  make_option("--tracks", type="character", default="processed/cyclone_tracks.rda",
              help="The file containing the cyclone tracks data  [default %default]"),
  make_option("--outpath", type="character", default="figs/map_2011_",
              help="Path to save figures [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))

load(opt$tracks)

# get the data
u250_m <- fread('http://iridl.ldeo.columbia.edu/SOURCES/.NOAA/.NCEP-NCAR/.CDAS-1/.MONTHLY/.Intrinsic/.PressureLevel/.u/T/%28April%202011%29VALUES/Y/%2890N%29%280S%29RANGEEDGES/X/%280E%29%28357.5E%29RANGEEDGES/P/%28250%29VALUES/gridtable.tsv', skip = 1)
names(u250_m) <- c('lon', 'lat', 'u250')
v250_m <- fread('http://iridl.ldeo.columbia.edu/SOURCES/.NOAA/.NCEP-NCAR/.CDAS-1/.MONTHLY/.Intrinsic/.PressureLevel/.v/T/%28April%202011%29VALUES/Y/%2890N%29%280S%29RANGEEDGES/X/%280E%29%28357.5E%29RANGEEDGES/P/%28250%29VALUES/gridtable.tsv', skip = 1)
names(v250_m) <- c('lon', 'lat', 'v250')
wind <- merge(u250_m, v250_m, by = c('lon', 'lat'))
wind[, lon := JamesR::Lon360to180(lon)]
wind[, magnitude := sqrt(u250^2 + v250^2)]
magnitude_max <- wind[, max(magnitude) * 1 / 2.5]
wind[, ':='(xstart = lon, xend = lon + u250 / magnitude_max, ystart = lat, yend = lat + v250 / magnitude_max)]

# consider the tracks
tracks <- cyclones[date_time >= ymd_h('2011-04-01 0') & date_time <= ymd_h('2011-04-30 18')]
tracks[, lon_prev := shift(lon, 1), by = stormnum]
tracks[, lon_diff := lon - lon_prev]
tracks[, cross_line := as.numeric(lon_diff < -100)]
tracks[, sum_diff := c(NA, cumsum(cross_line[-1])), by = stormnum]
tracks[sum_diff > 0, stormnum := stormnum * 5 + sum_diff]

# Rainfall Anomaly
rain <- fread('http://iridl.ldeo.columbia.edu/SOURCES/.NOAA/.NCEP/.CPC/.PRECL/.v1p0/.deg1p0/.rain/T/%28April%202011%29VALUES/Y/%280N%29%2889.5N%29RANGEEDGES/Y/%2820N%29%2870N5N%29RANGEEDGES/X/%28250E%29%28300E%29RANGEEDGES/Y/%2829N%29%2852N%29RANGEEDGES/X/%28100W%29%2860W%29RANGEEDGES/gridtable.tsv', skip = 1)
names(rain) <- c('lon', 'lat', 'prcp_mm')
rain <- rain[sample(1:nrow(rain), nrow(rain), replace = T, prob = rain$prcp_mm ^ 4)]
rain[, lon := JamesR::Lon360to180(lon)]

# plot the data
world <- map_data('world') %>% as.data.table()
storm_track <- 
  ggplot() +
  geom_polygon(data = world, aes(x = long, y = lat, group = group), fill = 'gray', color = 'gray') +
  geom_tile(data = wind[magnitude >= quantile(magnitude, 0.8)], aes(x = lon, y = lat, fill = magnitude), alpha = 0.9) +
  geom_path(data = world, aes(x = long, y = lat, group = group), color = 'gray', alpha = 0.6) +
  stat_ellipse(data = rain, aes(x=lon, y =lat), color = 'blue', type = "t", geom = 'polygon', fill = 'blue', alpha = 0.4) +
  geom_segment(data = wind[magnitude >= quantile(magnitude, 0.8)],
               size = 0.175, color = 'black',
               aes(x = xstart, xend = xend, y = ystart, yend = yend),
               arrow = arrow(length = unit(0.05, "cm")), alpha = 0.6) +
  scale_fill_distiller(palette = "YlOrRd", direction = 1) +
  geom_path(data = tracks, aes(x = lon, y = lat, group = stormnum)) +
  coord_map('orthographic', orientation = c(50, -82, 0)) +
  theme_map(base_size = 9) + 
  theme(legend.position = c(0.1, 0.1), panel.grid = element_line(color = 'black')) +
  labs(fill = "(m/s)")
storm_track %>% JamesR::EZPrint(fn = paste0(opt$outpath, 'flooding'), pdf = T, width = 6, height = 6)

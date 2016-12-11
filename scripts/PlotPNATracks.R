# -------- Packages and Options -------
pacman::p_load(data.table, magrittr, lubridate, ggplot2, ggthemes, locfit, optparse)
pacman::p_load_gh('jdossgollin/JamesR')

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--pna", type="character", default="processed/pna.rda",
              help="The file containing the TME data  [default %default]"),
  make_option("--tracks", type="character", default="processed/cyclone_tracks.rda",
              help="The file containing the cyclone tracks data  [default %default]"),
  make_option("--outpath", type="character", default="figs/pna_cyclone_",
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
dist_max <- 30
xl <- c(centroid[1] - dist_max - 5, centroid[1] + dist_max + 5)
yl <- c(centroid[2] - dist_max - 5, centroid[2] + dist_max + 5)
bsize <- 11

load(opt$tracks)
load(opt$pna)

# Subset the raw data
cyclones[, month := month(date_time)] # THIS IS OPEN FOR DISCUSSION
cyclones <- cyclones[month >= opt$month1 | month <= opt$month2]
pna <- pna[month(date) >= opt$month1 | month(date) <= opt$month2]

world <- map_data('world') %>% as.data.table()
setnames(world, 'long', 'lon')
world_rgn <- world[lon >= xl[1] & lon <= xl[2] & lat >= yl[1] & lat <= yl[2], unique(region)]
world <- world[region %in% world_rgn]

# Associate Cycone With PNA
cyclones[, date := as_date(date_time)]
cyclone_pna <- cyclones[, .(date_min = min(date), date_max = max(date)), by = stormnum]
cyclone_pna[, pna_mean := pna[date >= date_min & date <= date_max, mean(pna, na.rm = T)], by = stormnum]
cyclones <- merge(cyclones, cyclone_pna[,.(stormnum, pna_mean)], by = 'stormnum')
cyclones[, pna_cat := ifelse(pna_mean > quantile(pna$pna, 2/3,  na.rm = T), 1, ifelse(pna_mean > quantile(pna$pna, 1/3,  na.rm = T), 0, -1))]

# Cyclones that are near ORB
cyclones[, centroid_distance := sqrt((lon - centroid[1])^2 + (lat - centroid[2])^2)]
cyclones[, centroid_angle := atan2(lat - centroid[2], lon - centroid[1])]
cyclone_dist <- cyclones[, .(min_dist = min(centroid_distance)), by = stormnum]
cyclones_orb <- cyclones[stormnum %in% cyclone_dist[min_dist <= dist_max, stormnum]]
cyclones_orb <- na.omit(cyclones_orb)

idx_orb_plt <- cyclones_orb[lon >= xl[1] & lon <= xl[2] & lat >= yl[1] & lat <= yl[2]][, .(stormnum = sample(stormnum, 150), replace = F), by = pna_cat]
plt_tracks_pna <-
  cyclones_orb[stormnum %in% idx_orb_plt$stormnum][pna_cat %in% c(-1, 1)][, pna_cat := ifelse(pna_cat ==1, 'Positive', 'Negative')] %>%
  ggplot(aes(x = lon, y = lat)) +
  geom_polygon(data = world, aes(group = group), color = 'gray', fill = 'gray', alpha = 0.5) +
  geom_path(aes(group = stormnum, color = intensity)) +
  geom_rect(aes(xmin = opt$lonmin, xmax = opt$lonmax, ymin = opt$latmin, ymax = opt$latmax), fill = NA, color =  'black') +
  scale_color_distiller(palette = "YlOrRd", direction = 1) +
  facet_wrap('pna_cat') +
  theme_bw(base_size = bsize) +
  theme(panel.grid = element_line(color = 'black'), legend.position = c(0.95, 0.25)) +
  labs(x = "", y = "") +
  coord_map("albers", lat0 = 25, lat1 = 45, xlim = c(-120, -40), ylim = c(20, 70))
plt_tracks_pna %>% JamesR::EZPrint(fn = paste0(opt$outpath, 'map_plot'), pdf = T, height = 4.25, width = 10)

plt_heatmap_pna <-
  cyclones_orb[lon >= xl[1] & lon <= xl[2] & lat >= yl[1] & lat <= yl[2]] %>%
  ggplot(aes(x = lon, y = lat)) +
  geom_polygon(data = world, aes(group = group), color = 'gray', fill = 'gray', alpha = 0.5) +
  geom_hex(binwidth = c(2.5, 2.5), alpha = 0.8) +
  geom_rect(aes(xmin = opt$lonmin, xmax = opt$lonmax, ymin = opt$latmin, ymax = opt$latmax), fill = NA, color =  'black') +
  scale_fill_distiller(palette = "YlOrRd", direction = 1) +
  facet_wrap('pna_cat') +
  theme_bw(base_size = bsize) +
  theme(panel.grid = element_line(color = 'black'), legend.position = "bottom") +
  labs(x = "", y = "") +
  coord_quickmap(xlim = c(-120, -40), ylim = c(20, 70))
plt_heatmap_pna %>% JamesR::EZPrint(fn = paste0(opt$outpath, 'heatmap'), pdf = T, height = 5, width = 10)
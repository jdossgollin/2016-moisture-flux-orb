# -------- Packages and Options -------
pacman::p_load(data.table, magrittr, lubridate, ggplot2, ggmap, ggthemes, gridExtra, optparse)
pacman::p_load_gh('jdossgollin/JamesR')

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--shapefile", type="character", default = 'raw/BasinShapefile/FHP_Ohio_River_Basin_boundary',
              help="Path and file beginning for output figures  [default %default]"),
  make_option("--outpath", type="character", default="figs/map_",
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

# Some more rectangles to plot
source('config/gmx_box.R')
dipole <- list(high_x = c(-75, -62.5), high_y = c(30, 40), low_x = c(-95, -82.5), low_y = c(30, 40))


basin_points <- opt$shapefile %>%
  maptools::readShapePoly() %>%
  ggplot2::fortify() %>%
  data.table()

lon_boundary <- c(basin_points$long, dipole$high_x, gmx$lon)
lat_boundary <- c(basin_points$lat, dipole$high_y, gmx$lat)
boundary <- ggmap::make_bbox(lon_boundary, lat_boundary, f = 0.1)
latmin <- boundary[2]
latmax <- boundary[4]
lonmin <- boundary[1]
lonmax <- boundary[3]

# maps
world <- map_data('world') %>% as.data.table()
setnames(world, 'long', 'lon')
world_rgn <- world[lon >= lonmin & lon <= lonmax & lat >= latmin & lat <= latmax, unique(region)]
world <- world[region %in% world_rgn]
states <- map_data('state') %>% as.data.table()
setnames(states, 'long', 'lon')
states_rgn <- states[lon >= lonmin & lon <= lonmax & lat >= latmin & lat <= latmax, unique(region)]
states <- states[region %in% states_rgn]


station_map <-
  ggplot() +
  geom_polygon(data = world, aes(x = lon, y = lat, group = group), color = NA, fill = 'gray', alpha = 0.2) +
  geom_path(data = world[!(region %in% c('USA', 'Canada'))], aes(x = lon, y = lat, group = group), color = 'gray') +
  geom_path(data = states, aes(x = lon, y = lat, group = group), color = 'gray') +
  geom_polygon(aes(x = long,y = lat), fill = "gray", data = basin_points, alpha = 0.6, color = 'gray') +
  geom_rect(aes(xmin = opt$lonmin, xmax = opt$lonmax, ymin = opt$latmin, ymax = opt$latmax, color = "Moisture"), fill = NA) +
  geom_rect(aes(xmin = dipole$high_x[1], xmax = dipole$high_x[2], ymin = dipole$high_y[1], ymax = dipole$high_y[2], color = "W. Atl. Ridge"), fill = NA) +
  geom_rect(aes(xmin = gmx$lon[1], xmax = gmx$lon[2], ymin = gmx$lat[1], ymax = gmx$lat[2], color = "GMX"), fill = NA) +
  theme_bw(base_size = 10) +
  theme(panel.grid = element_line(color = 'black'), legend.position = "bottom") +
  coord_map("albers", lat0 = 25, lat1 = 45, xlim = c(lonmin, lonmax), ylim = c(latmin, latmax)) +
  labs(x = "Degrees East", y = "Degrees North", color = "")

station_map %>% JamesR::EZPrint(fn = paste0(opt$outpath, 'inset'), pdf = T, width = 6.5, height = 6.5*3/4)

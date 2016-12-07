# -------- Packages and Options -------
pacman::p_load(data.table, magrittr, lubridate, ggplot2, ggmap, ggthemes, gridExtra, optparse)
pacman::p_load_gh('jdossgollin/JamesR')

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--shapefile", type="character", default = 'raw/BasinShapefile/FHP_Ohio_River_Basin_boundary',
              help="Path and file beginning for output figures  [default %default]"),
  make_option("--outpath", type="character", default="figs/map_",
              help="Path and file beginning for output figures  [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))

basin_points <- opt$shapefile %>% 
  maptools::readShapePoly() %>% 
  ggplot2::fortify() %>% 
  data.table()

boundary <- ggmap::make_bbox(basin_points$long, basin_points$lat, f = 0)

# get boundaries from pre-defined file
latmin <- boundary[2] - 2
latmax <- boundary[4] + 2
lonmin <- boundary[1] - 5
lonmax <- boundary[3] + 5

station_map <-
  ggplot(map_data("state"), aes(x = long, y = lat)) + 
  geom_path(aes(group = group)) +
  geom_polygon(aes(x = long,y = lat),
               fill = "gray", data = basin_points, alpha = 0.4) +
  theme_map() +
  scale_alpha_continuous(range = c(0.2, 0.5), name = 'Years of Data') +
  coord_quickmap(xlim = c(lonmin, lonmax), ylim = c(latmin, latmax)) +
  theme(legend.position = "bottom")

map_inset <- 
  ggplot(map_data("state"), aes(x = long, y = lat)) + 
  geom_path(aes(group = group)) +
  geom_polygon(aes(x = long,y = lat),
               fill = "blue", data = basin_points, alpha = 0.8) +
  ylim(c(24, 50)) + xlim(-105, -65) +
  coord_quickmap() +
  theme_map() +
  theme(panel.background = element_rect(fill = "white",colour = NA))

p2_grob <- ggplotGrob(map_inset)
station_map <-
  station_map + 
  annotation_custom(grob = p2_grob,
                       xmin = lonmin, xmax = lonmin + 8, 
                       ymin = latmax - 4, ymax = latmax)

station_map %>% JamesR::EZPrint(fn = opt$outpath, pdf = T, width = 8, height = 6)
# -------- Packages and Options -------
pacman::p_load(data.table, magrittr, lubridate, ggplot2, ggthemes, optparse)
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
              help="Last year of data to collect [default %default]")
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

world <- map_data('world') %>% as.data.table()
setnames(world, 'long', 'lon')
world_rgn <- world[lon >= xl[1] & lon <= xl[2] & lat >= yl[1] & lat <= yl[2], unique(region)]
world <- world[region %in% world_rgn]

# Associate the Tracks & Moisture Flux Time Series
setnames(cyclones, 'date_time', 'time')
tracks <- merge(cyclones, q_mean, by = 'time')

dist_max <- 20
tracks[, centroid_distance := sqrt((lon - centroid[1])^2 + (lat - centroid[2])^2)]
close_tracks <- tracks[centroid_distance < dist_max][, .(lon, lat, dq)]


GetWeight <- function(lon, lat){
  mu <- c(-90, 43) + c(2,2)
  mu_bad <- c(-74, 37)
  sigma <- matrix(c(20, 8, 8, 14), 2, 2) * 3
  sigma_bad <- sigma * 4/5
  prob <- mvtnorm::dmvnorm(x = cbind(lon, lat), mean = mu, sigma = sigma) -
    0.4 * mvtnorm::dmvnorm(x = cbind(lon, lat), mean = mu_bad, sigma = sigma_bad)
  prob
}
lat_lon <- expand.grid(lon = seq(-100, -50, length.out = 50), lat = seq(20, 70, 0.1)) %>% as.data.table()
lat_lon[, prob := GetWeight(lon, lat)]
lat_lon[, prob_pos := prob < 0]
ggplot(tracks[month(time) > 10 | month(time) < 4], aes(x = lon, y = lat)) + 
  geom_polygon(data = world, aes(group = group), color = 'gray', fill = 'gray', alpha = 0.5) +
  geom_point(aes(color = dq), size = 1) +
  scale_color_gradient2() +
  geom_rect(aes(xmin = opt$lonmin, xmax = opt$lonmax, ymin = opt$latmin, ymax = opt$latmax), fill = NA, color =  'black') +
  geom_contour(data = lat_lon, aes(x = lon, y = lat, z = prob, linetype = prob_pos)) +
  coord_quickmap(ylim = range(lat_lon$lat), xlim = range(lat_lon$lon)) +
  guides(linetype = FALSE) + theme(legend.position = 'left') +
  theme_map()

tracks[, weight := GetWeight(lon, lat)]
tracks[, weight := (weight - mean(weight)) / sd(weight)]
ggplot(tracks[abs(weight) > 0.75], aes(x = weight, y = dq)) + geom_jitter() + geom_smooth()
ggplot(tracks, aes(x = weight, y = dq)) + geom_hex() + geom_smooth() 

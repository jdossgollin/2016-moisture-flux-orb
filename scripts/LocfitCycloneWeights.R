# -------- Packages and Options -------
pacman::p_load(data.table, magrittr, lubridate, ggplot2, ggthemes, locfit, rstan, optparse)
pacman::p_load_gh('jdossgollin/JamesR')

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--flux", type="character", default="processed/moisture.rda",
              help="The file containing the TME data  [default %default]"),
  make_option("--tracks", type="character", default="processed/cyclone_tracks.rda",
              help="The file containing the cyclone tracks data  [default %default]"),
  make_option("--latmin", type="integer", default="35",
              help="First year of data to collect [default %default]"),
  make_option("--latmax", type="integer", default="42.5",
              help="Last year of data to collect [default %default]"),
  make_option("--lonmin", type="integer", default="-90",
              help="First year of data to collect [default %default]"),
  make_option("--lonmax", type="integer", default="-77.5",
              help="Last year of data to collect [default %default]"),
  make_option("--outpath", type="character", default="figs/locfit_weight_",
              help="Path to save figures [default %default]"),
  make_option("--outfile", type="character", default="processed/locfit.rda",
              help="Path to save the fit [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))

# -------- Function -------
# Calculate distance in kilometers between two points
EarthDist <- function (long1, lat1, long2, lat2){
  rad <- pi/180
  a1 <- lat1 * rad
  a2 <- long1 * rad
  b1 <- lat2 * rad
  b2 <- long2 * rad
  dlon <- b2 - a2
  dlat <- b1 - a1
  a <- (sin(dlat/2))^2 + cos(a1) * cos(b1) * (sin(dlon/2))^2
  c <- 2 * atan2(sqrt(a), sqrt(1 - a))
  R <- 6378.145
  d <- R * c
  return(d)
}

# -------- Make the Locfit Model -------

xl <- c(-110, -40)
yl <- c(25, 70)
centroid <- c(-83.5, 42.0)

load(opt$tracks)
load(opt$flux)
q_mean[, dq := dq / 1e4] # new units

# select the closest cyclone each day, DJF only
cyclones <- cyclones[season == 'DJF', .(lon, lat, date_time)]
cyclones[, dist := EarthDist(long1 = lon, lat1 = lat, long2 = centroid[1], lat2 = centroid[2])]
cyclones <- cyclones[, .SD[which.min(dist)], by = date_time]

# get data on the flux
cyclones <- merge(cyclones, q_mean[, .(date_time = time, dq)], by = 'date_time')
#m <- m[lon >= xl[1] & lon <= xl[2]]
cyclones[, prob := (dq - min(dq))][, prob := prob / sum(prob)] # re-weighted

# sample based on associated moisture transport
N <- nrow(cyclones) * 5
idx <- sample(1:nrow(cyclones), N, replace = T, prob = cyclones[, prob])
sampled <- cyclones[idx]

# conduct a locfit with a hard threshold on distance
sampled_close <- sampled[dist <= 2500][lat >= 30]
locfit_model <- locfit(data = sampled_close, dq ~ lon + lat, alpha = 0.5) 
# plot(locfit_model, type = 'image')

# ----- A Clear Function -----
GetWeight <- function(lon, lat, model = locfit_model){
  centroid <- c(-83.5, 42.0)
  dt <- data.table(lon = lon, lat = lat)
  dt[, dist := EarthDist(long1 = lon, lat1 = lat, long2 = centroid[1], lat2 = centroid[2])]
  dt[, predicted := predict(locfit_model, as.matrix(dt[, .(lon, lat)]))]
  # discount for distance
  dt[, ':='(dx = abs(lon - centroid[1]), dy = abs(lat - centroid[2]))]
  dt[, predicted := predicted * exp(-(dist / 1750)^2)] # hard threshold
  return(dt$predicted)
}

# ----- Plots -----

world <- map_data('world') %>% as.data.table()
setnames(world, 'long', 'lon')
world_rgn <- world[lon >= xl[1] & lon <= xl[2] & lat >= yl[1] & lat <= yl[2], unique(region)]
world <- world[region %in% world_rgn]

test <- expand.grid(lon = seq(xl[1], xl[2], 0.5), lat = seq(yl[1], yl[2], 0.5)) %>% as.data.table()
test[, norm := GetWeight(lon = lon, lat = lat, model = locfit_model)]
test[, norm := norm / max(norm)]


baseplot <- 
  ggplot() +
  theme_bw(base_size = 10) +
  theme(legend.position = "left", panel.grid = element_line(color = 'black')) +
  coord_quickmap(xlim = xl, ylim = yl) +
  scale_fill_distiller(palette = "Blues", name = "", breaks = NULL) +
  labs(x = "", y = "")

plot_comparison <-
  baseplot +
  geom_hex(data = sampled, binwidth = c(2.5, 2.5), aes(x = lon, y = lat, fill = ..density..)) +
  geom_path(data = world, aes(x = lon, y = lat, group = group)) +
  geom_contour(data = test, aes(x = lon, y = lat, z = norm), color = 'black') +
  geom_rect(aes(xmin = opt$lonmin, xmax = opt$lonmax, ymin = opt$latmin, ymax = opt$latmax), fill = NA, color =  'black') +
  labs(caption = "Color indicates density of observed cyclones, weighted by moisture flux; contours are from local regression")
plot_comparison %>% JamesR::EZPrint(fn = paste0(opt$outpath, 'predicted_observed'), pdf = T, width = 9, height = 8)

plot_model <-
  baseplot +
  geom_raster(data = test, aes(x = lon, y = lat, fill = norm)) +
  geom_path(data = world, aes(x = lon, y = lat, group = group)) +
  geom_contour(data = test, aes(x = lon, y = lat, z = norm), color = 'black')
plot_model %>% JamesR::EZPrint(fn = paste0(opt$outpath, 'predicted_only'), pdf = T, width = 9, height = 8)

# ----- Save the Fit -----

save(locfit_model, EarthDist, GetWeight, file = opt$outfile)

# A Function to take the latitude and longitude of a point (cyclone center)
# and return a score (weighting function)
CycloneWeight <- function(lon, lat, method){
  if(method == 'parallelogram'){
    pgram_coords <- data.frame(x = c(-89, -77, -89, -101), y = c(37, 48, 48, 37))
    #plt_track_moisture + geom_polygon(data = pgram_coords, aes(x = x, y = y), fill = NA, color = 'black')
    weights <- sp::point.in.polygon(point.x = lon, point.y = lat, pol.x = pgram_coords$x, pol.y = pgram_coords$y)
  } else {
    stop('invalid method passed to CycloneWeight')
  }
  return(weights)
}

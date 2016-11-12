# -------- Packages and Options -------
pacman::p_load_gh('jdossgollin/JamesR')
pacman::p_load(data.table, magrittr, optparse, lubridate)

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--rawfile", type="character", default="processed/tmev2.rda",
              help="d [default %default]"),
  make_option("--gridsize", type="double", default="2.5",
              help="To how many degrees should TME data be gridded [default %default]"),
  make_option("--outfile", type="character", default="processed/gridded_tmev2.rda",
              help="Name of .rda file to store TME time series  [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))

# -------- Function Definitions -------

GridData <- function(dt, grid_size = c(2.5, 2.5), daily = TRUE){
  require(data.table)
  require(magrittr)
  require(lubridate)
  
  # calculate change in Q
  setkey(dt, traj_id, hrs_fwd)
  dt[, dQ := c(NA, diff(Q)), by = traj_id]
  dt[, dQ := -dQ] # correction
  
  # round the lat & lon
  dt[, c('lon_r', 'lat_r') := .(JamesR::RoundTo(lon, to = grid_size[1], method = "nearest"),
                                JamesR::RoundTo(lat, grid_size[2], method = "nearest"))]
  
  # set the lon to 0-360 usage
  dt[lon_r == 360, lon_r := lon_r - grid_size[1]]
  
  # sum
  if(daily) dt[, date_time := lubridate::as_date(date_time)]
  setkey(dt, lon_r, lat_r, date_time)
  dt <- na.omit(dt)
  gridded <- dt[, .(dQ = sum(dQ)), by = .(lon_r, lat_r, date_time)]
  setnames(gridded, c('lon_r', 'lat_r'), c('lon', 'lat'))
  
  return(gridded)
}

# -------- Begin Script -------

load(opt$rawfile)
tme <- tme[order(traj_id,start_date,init_point,hrs_fwd)]
gridded <- GridData(tme, grid_size = rep(opt$gridsize, 2), daily = FALSE)

save(gridded, file = opt$outfile)
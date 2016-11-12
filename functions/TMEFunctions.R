Array2dt <- function(array){
  require(abind)
  require(data.table)

  dim <- dim(array)
  dimnames <- dimnames(array)
  idx_dir <- which.min(dim) # direction to move along

  dt_list <- vector('list', dim[idx_dir])
  for(i in 1:dim[idx_dir]){
    if (idx_dir == 1) {
      idx_str <- '[i, , ]'
    } else if (idx_dir == 2) {
      idx_str <- '[, i, ]'
    } else if (idx_dir == 3) {
      idx_str <- '[, , i]'
    }
    expr <- parse(text = paste0('array', idx_str))
    array_i <- eval(expr)
    if(dim[3] > dim[2]) array_i <- t(array_i)
    dt_list[[i]] <- data.table(array_i)
    dt_list[[i]][, idx_a := dimnames(array)[[2]]]
    dt_list[[i]] <- melt(dt_list[[i]], id.vars = 'idx_a', variable.name = 'idx_b')
    dt_list[[i]][, idx_c := dimnames[[idx_dir]][i]]
  }
  dt_list <- rbindlist(dt_list)
  return(dt_list)
}

DownloadRaw <- function(year_vec, data_path){
  require(curl)
  var <- c('Q', 'lat', 'lon')
  destfile <- paste0(data_path, 'tme_v2_', var, '_', year_vec, '.nc')
  if(!all(file.exists(destfile))){
    login <- list(user = readline("Type the username:"),
                  password = readline("Type the password:"))
    for(year in year_vec){
      for(var in c('Q', 'lat', 'lon')){
        destfile <- paste0(data_path, 'tme_v2_', var, '_', year, '.nc')
        if(!file.exists(destfile)){
          # create the raw file url
          url <- paste0('http://', login$user, ':', login$password, '@iridl.ldeo.columbia.edu/SOURCES/.U_Mainz/.IAP/.TMEv2/.nh/.', var, '/S/%280000%201%20Jan%20', year, '%29%280000%2031%20Dec%20', year, '%29RANGEEDGES/data.nc')
          # do the download
          tf <- curl_download(url, destfile, quiet = TRUE, mode = "wb", handle = new_handle())
        }
      }
    }
  }
}


ReadYear <- function(year, data_path){
  require(ncdf4)
  require(magrittr)
  require(data.table)
  require(lubridate)
  require(JamesR)
  # ----- STEP 1: READ IN THE RAW DATA -----
  # get the file names
  files <- Sys.glob(paste0(data_path, '*_', year, '.nc'))
  lon_file <- files[grep('lon', files)]
  lat_file <- files[grep('lat', files)]
  Q_file <- files[grep('Q', files)]
  # read in the three files
  nc <- nc_open(lon_file)
  lon <- ncvar_get(nc, varid = 'lon')
  dimnames(lon) <- list(nc$dim$L$vals, nc$dim$track$vals, nc$dim$S$vals)
  # save the units
  units <- list(
    L = nc$dim$L$units,
    track = nc$dim$track$units,
    S = nc$dim$S$units,
    lon = nc$var$lon$units
  )
  # close the raw path
  nc_close(nc)
  # repeat for lat and Q
  nc <- nc_open(lat_file)
  lat <- ncvar_get(nc, varid = 'lat')
  dimnames(lat) <- list(nc$dim$L$vals, nc$dim$track$vals, nc$dim$S$vals)
  units$lat <- nc$var$lat$units
  nc_close(nc)
  # Q
  nc <- nc_open(Q_file)
  Q <- ncvar_get(nc, varid = 'Q')
  dimnames(Q) <- list(nc$dim$L$vals, nc$dim$track$vals, nc$dim$S$vals)
  units$Q <- nc$var$Q$units
  nc_close(nc)
  # sanity check
  if(any(c(dim(lat) != dim(lon), dim(lon) != dim(Q)))) stop('Variable dimensions are off -- something is off with the files')
  # ----- STEP 2: CONVERT TO DATA.TABLE AND JOIN -----
  lon_x <- Array2dt(lon); setnames(lon_x, 'value', 'lon')
  lat_x <- Array2dt(lat); setnames(lat_x, 'value', 'lat')
  Q_x <- Array2dt(Q); setnames(Q_x, 'value', 'Q')
  dt <- cbind(lon_x, lat = lat_x[, lat], Q = Q_x[, Q])
  setnames(dt, c('idx_a', 'idx_b', 'idx_c'), c('init_point', 'start_date', 'hrs_fwd'))
  # remove missing values
  dt <- na.omit(dt)
  # fix the structure
  dt[, init_point := as.numeric(init_point)]
  dt[, start_date := JamesR::as.numeric.factor(start_date)]
  dt[, hrs_fwd := as.numeric(hrs_fwd)]
  # parse out some dates -- slow unfortunately but very useful
  dt[, start_date := as.POSIXct(lubridate::ymd_h('1960-01-01 0') + days(start_date))]
  dt[, date_time := as.POSIXct(start_date + lubridate::hours(hrs_fwd))]
  # create an ID for each trajectory
  setkey(dt, init_point, start_date)
  dt[, traj_id := .GRP, by = .(init_point, start_date)]
  # all set
  dt <- dt[, .(start_date, init_point, traj_id, hrs_fwd, date_time, lon, lat, Q)]
  return(dt)
}

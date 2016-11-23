# -------- Packages and Options -------

pacman::p_load(data.table, magrittr, ncdf4, lubridate, optparse)
pacman::p_load_gh('jdossgollin/JamesR')

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
option_list <- list(
  make_option("--trackpath", type="character", default="~/Documents/Work/Data/cyclone/",
              help="Path to folder where cyclone tracks are stored [default %default]"),
  make_option("--syear", type="integer", default="1979",
              help="First year of data to collect [default %default]"),
  make_option("--eyear", type="integer", default="2013",
              help="Last year of data to collect [default %default]"),
  make_option("--outfile", type="character", default="processed/cyclone_tracks.rda",
              help="Name of .rda file to store gridded tidy cyclone tracks  [default %default]")
)
opt <- parse_args(OptionParser(option_list=option_list))


# -------- Function Definitions -------

ReadCycloneNC <- function(fn){
  require(ncdf4)
  require(data.table)
  require(lubridate)
  require(magrittr)
  
  nc <- nc_open(fn)
  
  # the dimensions
  stormnum <- ncvar_get(nc, varid = 'stormnum')
  trackpos <- ncvar_get(nc, varid = 'trackpos')
  
  # the variables, indexed [trackpos, stormnum] before transpose
  vars <- c('hour', 'day', 'month', 'year', 'centerpr', 'Intensity', 'lat', 'lon')
  for(i in 1:length(vars)){
    vari <- vars[i]
    vali <- ncvar_get(nc, varid = vari) %>% t() %>% as.data.table()
    vali[, stormnum := stormnum]
    vali <- melt(vali, id.vars = 'stormnum', variable.name = 'trackpos', value.name = vari)
    vali[, trackpos := tstrsplit(trackpos, 'V')[2]]
    vali[, trackpos := as.numeric(trackpos)]
    if(i == 1){
      dt <- vali
    } else {
      dt <- cbind(dt, vali[, vari, with = F])
    }
  }
  nc_close(nc)
  dt <- na.omit(dt)
  dt[, date := ymd_h(paste(year, month, day, hour))]
  dt[, ':='(year = NULL, month = NULL, day = NULL, hour = NULL)]
  setkey(dt, 'stormnum', 'trackpos')
  
  # set longitudes to standard -180 to 180 form
  dt[, lon := JamesR::Lon360to180(lon)]
  dt[, date0 := .SD[1, date], by = stormnum]
  dt[, season := GetSeasonDate(date0)]
  
  return(dt)
}

# -------- Begin Script -------

ncfiles <- Sys.glob(paste0(opt$trackpath, '*.nc'))
cyclones <- vector('list', length(ncfiles))

for(i in 1:length(ncfiles)){
  cyclones[[i]] <- ReadCycloneNC(ncfiles[i])
}
cyclones <- rbindlist(cyclones)
cyclones[, stormnum2 := .GRP, by = .(stormnum, date0)]
cyclones[, stormnum := NULL]
setnames(cyclones, 'stormnum2', 'stormnum')
cyclones <- cyclones[year(date0) >= opt$syear & year(date0) <= opt$eyear]
save(cyclones, file = opt$outfile)

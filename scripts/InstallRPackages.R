my_lib <- .libPaths()[1]
my_repo <- 'http://cran.cnr.berkeley.edu/'

if(!require(pacman)){
  install.packages('pacman')
  require(pacman)
}
package_list <- c('data.table', 'magrittr', 'readxl', 'lubridate', 'readr', 'ggplot2',
                  'ggthemes', 'leaflet', 'ggmap', 'maptools', 'ggmap',
                  'geosphere', 'sp', 'rgeos', 'stringr', 'WaveletComp')
pacman::p_load(package_list, character.only = TRUE)

pacman::p_load_gh('jdossgollin/cpcRain')
pacman::p_load_gh('jdossgollin/JamesR')

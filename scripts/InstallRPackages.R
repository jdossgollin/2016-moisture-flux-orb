my_lib <- .libPaths()[1]
my_repo <- 'http://cran.cnr.berkeley.edu/'

if(!require(pacman)){
  install.packages('pacman')
  require(pacman)
}
package_list <- c('curl', 'data.table', 'magrittr', 'ncdf4', 'arrayhelpers',
                  'ggplot2', 'ggthemes', 'optparse', 'lubridate', 'abind', 'xts')
pacman::p_load(package_list, character.only = TRUE)

pacman::p_load_gh('jdossgollin/JamesR')

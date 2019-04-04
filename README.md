# ORB- Moisture-Flux

## Goal

- Study of moisture flux into the Ohio River Basin
- this work was presented at AGU Fall Meeting 2016 but never written up or published

## Requirements

You will need:

- python version 2 or 3; if you are using version 2, change the `python3` commands in the `makefile` to `python`. However, since python is not used heavily, all code is compatible for either version 2 or 3
- the ECMWF Python API module, available following the instructions at [https://software.ecmwf.int/wiki/display/WEBAPI/Accessing+ECMWF+data+servers+in+batch](https://software.ecmwf.int/wiki/display/WEBAPI/Accessing+ECMWF+data+servers+in+batch)
- A recent version of R and an ability to install packages using the `pacman` package management package (see `scripts/InstallRPackages.R`)
- Modest ($\mathcal{O}(1 \text{GB})$) of storage space (approximately)
- Ability to install the R `ncdf4` package, which describes on several C libraries; instructions for downloading are available at the package website [https://cran.r-project.org/web/packages/ncdf4/index.html](https://cran.r-project.org/web/packages/ncdf4/index.html) in the package manual and are straightforward but need to be completed

## Running

Clone the repository to your desktop using `git clone` or download as a zipped folder

1. Edit parameters in the `config/` folder
2. Change `python3` to `python` if desired in `makefile`
3. ` make all`

This will take some time as the scripts are currently set to download moisture flux and geopotential height data from the ECMWF servers, which can take some time.

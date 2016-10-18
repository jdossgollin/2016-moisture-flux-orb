# ORB-daily-rainfall

Farnham &amp; Doss-Gollin &amp; Lall: Work in Progress

## About

Space-time dynamics of extreme daily rainfall

## Requirements

You will need:

- **R** (sufficiently recent version)
- access to the internet
- space on your computer for ncdf files
- the `C` libraries required for the **R** `ncdf4` package; details are specified [here](https://cran.r-project.org/web/packages/ncdf4/ncdf4.pdf).
- A shell terminal
- `make` (comes standard on most UNIX-based operating systems)

## To Run

1. Download to your computer or `git clone`
2. Edit the `SetDataPaths.R` file to specify the folders where you would like to store your `ncdf` files. The files downloaded are quite large: about 500 MB per variable per year, times >60 years, times 3 variables (plus a small one).
3. Run `make all` in a terminal

This will take a while -- a lot of data needs to be downloaded (unless it is already in the specified folder) from the NOAA servers, and then some non-trivial computations need to be run.

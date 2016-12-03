## all	:	run everything
all	:	dependencies processed figs

# these files contain options for running the code

## dependencies	: Install R Packages
.PHONY	:	dependencies
dependencies	: scripts/InstallRPackages.R
	Rscript $^
	mkdir -p figs
	mkdir -p processed
	mkdir -p reanalysis

# file paths and other options
include config/*.mk

# GET REANALYSIS DATA
GRIDSIZE=1.0
moisture_nc=reanalysis/moisture.nc
dlow_nc=reanalysis/dipolelow.nc
dhigh_nc=reanalysis/dipolehigh.nc

$(moisture_nc)	:	scripts/moisture_flux.py config/moisturebox.mk config/dates.mk
	python3 $< --outfile $(moisture_nc) --bound $(MBNORTH) $(MBWEST) $(MBSOUTH) $(MBEAST) --grid $(GRIDSIZE) --syear $(SYEAR) --eyear $(EYEAR)
$(dlow_nc)	:	scripts/download_dipole.py config/dipoleLow.mk config/dates.mk
	python3 $< --outfile $(dlow_nc) --bound $(DLNORTH) $(DLWEST) $(DLSOUTH) $(DLEAST) --grid $(GRIDSIZE) --syear $(SYEAR) --eyear $(EYEAR)
$(dhigh_nc)	:	scripts/download_dipole.py config/dipoleHigh.mk config/dates.mk
	python3 $< --outfile $(dhigh_nc) --bound $(DHNORTH) $(DHWEST) $(DHSOUTH) $(DHEAST) --grid $(GRIDSIZE) --syear $(SYEAR) --eyear $(EYEAR)

## reanalysis	:	access reanalysis data
reanalysis	: $(moisture_nc) $(dlow_nc) $(dhigh_nc)

# How big to make the grids


# THE PROCESSED DATA
dipole_ts=processed/dipole_ts.rda
pna_rda=processed/pna.rda
tme_rda=processed/tme.rda
tme_grid=processed/tme_gridded.rda
tme_ts=processed/tme_ts.rda
moisture_rda=processed/moisture.rda
cyclone_rda=processed/cyclone_tracks.rda

$(dipole_ts)	:	scripts/GetDipoleTS.R $(dlow_nc) $(dhigh_nc)
	Rscript $< --nchigh=$(dhigh_nc) --nclow=$(dlow_nc) --outfile=$(dipole_ts)
$(pna_rda)	:	scripts/GetPNA.R config/dates.mk
	Rscript $< --syear=$(SYEAR) --eyear=$(EYEAR) --lag=30 --outfile=$(pna_rda)
$(tme_rda)	:	scripts/GetTME.R config/dates.mk config/moisturebox.mk
	Rscript $< --tmepath="~/Documents/Work/Data/TMEv2/" --syear=$(SYEAR) --eyear=$(EYEAR) --latmin=$(MBSOUTH) --latmax=$(MBNORTH) --lonmin=$(MBWEST) --lonmax=$(MBEAST) --outfile=$(tme_rda)
$(tme_grid)	:	scripts/GetGriddedTME.R $(tme_rda)
	Rscript $< --rawfile=$(tme_rda) --gridsize=$(GRIDSIZE) --outfile=$(tme_grid)
$(tme_ts)	:	scripts/GetTMETS.R $(tme_grid) config/moisturebox.mk
	Rscript $< --gridded=$(tme_grid) --latmin=$(MBSOUTH) --latmax=$(MBNORTH) --lonmin=$(MBWEST) --lonmax=$(MBEAST) --outfile=$(tme_ts)
$(moisture_rda)	:	scripts/ReadMoistureFlux.R $(moisture_nc)
	Rscript $< --infile=$(moisture_nc) --outfile=$(moisture_rda)
$(cyclone_rda)	:	scripts/GetCycloneTracks.R config/dates.mk config/moisturebox.mk
	Rscript $< --trackpath="~/Documents/Work/Data/cyclone/"  --syear=$(SYEAR) --eyear=$(EYEAR) --outfile=$(cyclone_rda)

## processed	:	read and analyze data sets
processed	:  reanalysis $(dipole_ts) $(pna_rda) $(tme_rda) $(tme_grid) $(tme_ts) $(moisture_rda) $(cyclone_rda)


# FIGURES
figs/moisture_cyclone_*.pdf	: scripts/PlotCycloneMoisture.R	$(moisture_rda) $(cyclone_rda) config/moisturebox.mk
	Rscript $< --flux=$(moisture_rda) --tracks=$(cyclone_rda) --latmin=$(MBSOUTH) --latmax=$(MBNORTH) --lonmin=$(MBWEST) --lonmax=$(MBEAST) --outpath="figs/moisture_cyclone_"

## figs	:	make the plots
figs	:	figs/moisture_cyclone_*.pdf

## clean	:	reset to original (only raw data and scripts)
clean	:
	rm -rf figs processed

## view	:	open all the pdf figures
pdf_viewer = Preview # edit as desired
view	:
	open -a $(pdf_viewer) figs/*.pdf

.PHONY : help
help : Makefile
	@sed -n 's/^##//p' $<

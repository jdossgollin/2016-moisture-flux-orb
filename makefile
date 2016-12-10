#------ SETUP ------#

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
	mkdir -p bayesian

# file paths and other options
include config/*.mk


#------ GET REANALYSIS DATA ------#

moisture_nc=reanalysis/moisture.nc # moisture flux into the box
gph_nc=reanalysis/gph.nc # northern hemisphere GPH heights
tmp_nc=reanalysis/temperature.nc # northern hemisphere 2m temperatures

# moisture flux only over the specified box
$(moisture_nc)	:	scripts/moisture_flux.py config/moisturebox.mk config/dates.mk
	python3 $< --outfile $(moisture_nc) --bound $(MBNORTH) $(MBWEST) $(MBSOUTH) $(MBEAST) --grid 1.0 --syear $(SYEAR) --eyear $(EYEAR)
# Z600 Z850 and SST over all northern hemisphere
$(gph_nc)	:	scripts/download_gph.py config/dates.mk
	python3 $< --outfile $(gph_nc) --bound 90 -180 0 180 --grid 2.5 --syear $(SYEAR) --eyear $(EYEAR)
$(tmp_nc)	:	scripts/download_temp.py config/dates.mk
	python3 $< --outfile $(tmp_nc) --bound 90 -180 0 180 --grid 2.5 --syear $(SYEAR) --eyear $(EYEAR)

## reanalysis	:	access reanalysis data
reanalysis	: $(moisture_nc) $(gph_nc) $(tmp_nc)


#------ RAW TO PROCESSED DATA ------#

dipole_ts=processed/dipole_ts.rda
pna_rda=processed/pna.rda
temp_rda=processed/temperature.rda
moisture_rda=processed/moisture.rda
cyclone_rda=processed/cyclone_tracks.rda
amo_rda=processed/amo.rda
locfit_rda=processed/locfit_model.rda

$(dipole_ts)	:	scripts/GetDipoleTS.R $(gph_nc)
	Rscript $< --gphnc=$(gph_nc) --outfile=$(dipole_ts)
$(pna_rda)	:	scripts/GetPNA.R config/dates.mk
	Rscript $< --syear=$(SYEAR) --eyear=$(EYEAR) --lag=30 --outfile=$(pna_rda)
$(amo_rda)	:	scripts/GetAMO.R config/dates.mk
	Rscript $< --syear=$(SYEAR) --eyear=$(EYEAR) --outfile=$(amo_rda)
$(moisture_rda)	:	scripts/ReadMoistureFlux.R $(moisture_nc)
	Rscript $< --infile=$(moisture_nc) --outfile=$(moisture_rda)
$(cyclone_rda)	:	scripts/GetCycloneTracks.R config/dates.mk config/moisturebox.mk
	Rscript $< --trackpath="~/Documents/Work/Data/cyclone/"  --syear=$(SYEAR) --eyear=$(EYEAR) --outfile=$(cyclone_rda)
$(temp_rda)	:	scripts/ReadTemperature.R config/gmx_box.R config/dates.mk
	Rscript $< --infile=$(tmp_nc) --gmx_box=config/gmx_box.R --outfile=$(temp_rda)
$(locfit_rda)	:	scripts/LocfitCycloneWeights.R $(cyclone_rda) $(moisture_rda) config/moisturebox.mk
	Rscript $< --flux=$(moisture_rda) --tracks=$(cyclone_rda) --latmin=$(MBSOUTH) --latmax=$(MBNORTH) --lonmin=$(MBWEST) --lonmax=$(MBEAST) --outpath="figs/locfit_weight_" --outfile=$(locfit_rda)

## processed	:	read and analyze data sets
processed	:  reanalysis $(dipole_ts) $(pna_rda) $(amo_rda) $(moisture_rda) $(cyclone_rda) $(temp_rda) $(locfit_rda)

#------ MAKE PLOTS ------#

figs/moisture_cyclone_*.pdf	:	scripts/PlotCycloneMoisture.R $(moisture_rda) $(cyclone_rda)
	Rscript $< --flux=$(moisture_rda) --tracks=$(cyclone_rda) --outpath="figs/moisture_cyclone_"  --latmin=$(MBSOUTH) --latmax=$(MBNORTH) --lonmin=$(MBWEST) --lonmax=$(MBEAST) --month1=$(SMONTH) --month2=$(EMONTH)
figs/pna_cyclone_*.pdf	: scripts/PlotPNATracks.R	$(pna_rda) $(cyclone_rda) config/moisturebox.mk
	Rscript $< --pna=$(pna_rda) --tracks=$(cyclone_rda) --latmin=$(MBSOUTH) --latmax=$(MBNORTH) --lonmin=$(MBWEST) --lonmax=$(MBEAST) --outpath="figs/pna_cyclone_" --month1=$(SMONTH) --month2=$(EMONTH)
figs/map_*.pdf	:	scripts/MapStations.R raw/BasinShapefile/FHP_Ohio_River_Basin_boundary.* config/moisturebox.mk
	Rscript $< --shapefile="raw/BasinShapefile/FHP_Ohio_River_Basin_boundary"  --latmin=$(MBSOUTH) --latmax=$(MBNORTH) --lonmin=$(MBWEST) --lonmax=$(MBEAST) --outpath="figs/map_"
figs/flooding_2011_*.pdf	:	scripts/PlotApril2011.R $(moisture_rda) $(cyclone_rda)
	Rscript $< --flux=$(moisture_rda) --tracks=$(cyclone_rda) --outpath="figs/flooding_2011_"

## figs	:	make the plots
figs	:	figs/moisture_cyclone_*.pdf figs/pna_cyclone_*.pdf figs/map_*.pdf figs/flooding_2011_*.pdf

#------ STATISTICAL ANALYSIS ------#


#------ CLEAN AND VIEW ------#
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

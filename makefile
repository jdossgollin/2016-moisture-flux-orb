## all	:	run everything
all	:	dependencies processed figs

# these files contain options for running the code

## dependencies	: Install R Packages
.PHONY	:	dependencies
dependencies	: scripts/InstallRPackages.R
	Rscript $^
	mkdir -p figs
	mkdir -p processed

# file paths and other options
include config/*.mk

# How big to make the grids
GRIDSIZE=1.0

# THE PROCESSED DATA
dipole_ts=processed/dipole_ts.rda
pna_rda=processed/pna.rda
moisture_nc=processed/moisture.nc
dlow_nc=processed/dipolelow.nc
dhigh_nc=processed/dipolehigh.nc

$(moisture_nc)	:	scripts/moisture_flux.py config/moisturebox.mk config/dates.mk
	python3 $< --outfile $(moisture_nc) --bound $(MBNORTH) $(MBWEST) $(MBSOUTH) $(MBEAST) --grid $(GRIDSIZE) --syear $(SYEAR) --eyear $(EYEAR)
$(dlow_nc)	:	scripts/download_dipole.py config/dipoleLow.mk config/dates.mk
	python3 $< --outfile $(moisture_nc) --bound $(DLNORTH) $(DLWEST) $(DLSOUTH) $(DLEAST) --grid $(GRIDSIZE) --syear $(SYEAR) --eyear $(EYEAR)
$(dhigh_nc)	:	scripts/download_dipole.py config/dipoleHigh.mk config/dates.mk
	python3 $< --outfile $(moisture_nc) --bound $(DHNORTH) $(DHWEST) $(DHSOUTH) $(DHEAST) --grid $(GRIDSIZE) --syear $(SYEAR) --eyear $(EYEAR)
#$(dipole_ts)	:	scripts/GetDipoleTS.R $(dipole_nc) processed/dipole_high.nc processed/dipole_low.nc
#	Rscript $<  --nchigh="processed/dipole_high.nc" --nclow="processed/dipole_low.nc" --outfile=$(dipole_ts)
#$(pna_rda)	:	scripts/GetPNA.R config/dates.mk
#	Rscript $< --syear=$(syear) --eyear=$(eyear) --outfile=$(pna_rda)

## processed	:	read and analyze data sets
processed	: $(moisture_nc) $(dlow_nc) $(dhigh_nc)




# FIGURES


## figs	:	make the plots
figs	:

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

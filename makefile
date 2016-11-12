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

# THE PROCESSED DATA
tme_rda=processed/tmev2.rda
gridded_rda=processed/gridded_tmev2.rda
tme_ts=processed/tme_ts.rda

$(tme_rda)	:	scripts/GetTME.R config/dates.mk config/paths.mk config/spatial.mk
	Rscript $< --tmepath=$(tme_path) --syear=$(syear) --eyear=$(eyear) --gridsize=$(gridsize) --lonmin=$(lonmin) --lonmax=$(lonmax) --latmin=$(latmin) --latmax=$(latmax) --outfile=$(tme_rda)
$(gridded_rda)	:	scripts/GetGriddedTME.R config/spatial.mk
	Rscript $< --rawfile=$(tme_rda) --gridsize=$(gridsize) --outfile=$(gridded_rda)
$(tme_ts)	:	scripts/GetTMETimeSeries.R config/spatial.mk
	Rscript $< --rawfile=$(gridded_rda) --outfile=$(tme_ts) --lonmin=$(lonmin) --lonmax=$(lonmax) --latmin=$(latmin) --latmax=$(latmax)


## processed	:	read and analyze data sets
processed	:	$(tme_rda) $(gridded_rda) $(tme_ts)



# FIGURES
figs/tme_plot_*.pdf	:	scripts/PlotRawTME.R
	Rscript $< --tmepath=$(tme_rda) --gridpath=$(gridded_rda) --tspath=$(tme_ts) --out_path="figs/tme_plot_" --pdf=TRUE

## figs	:	make the plots
figs	:	figs/tme_plot_*.pdf

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

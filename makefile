## all	:	run everything
all	:	dependencies processed figs

# these files contain options for running the code

## dependencies	: Install R Packages
.PHONY	:	dependencies
dependencies	: scripts/InstallRPackages.R
	Rscript $^
	mkdir -p figs
	mkdir -p processed


# THE PROCESSED DATA


## processed	:	read and analyze data sets
processed	:



## figs	:	make the plots
figs	:	



## clean	:	reset to original (only raw data and scripts)
clean	:
	rm -rf figs processed

.PHONY : help
help : Makefile
	@sed -n 's/^##//p' $<

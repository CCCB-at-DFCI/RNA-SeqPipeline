# Checks for the necessary R packages:

is.installed <- function(lib) is.element(lib, installed.packages()[,1]) 

source("http://bioconductor.org/biocLite.R")

tryCatch(
		{
			if(!is.installed("DESeq")){biocLite("DESeq")}
			if(!is.installed("RColorBrewer")){install.packages("RColorBrewer")}
			if(!is.installed("gplots")){install.packages("gplots")}
		},
		error = function()
		{
			stop("There was an error checking and installing R dependencies.  Please read the documentation and manually install the required packages.")
		}
)

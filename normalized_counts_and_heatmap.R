#libraries for this script:
if(!require("DESeq", character.only=T)) stop("Please install the DESeq package first.")
if(!require("RColorBrewer", character.only=T)) stop("Please install the RColorBrewer package first.")
if(!require("gplots", character.only=T)) stop("Please install the gplots package first.")

#get args from the commandline:
# 1: full path to the output directory
# 2: full path to the design matrix file
# 3: name for the file we will write to that will contain the normalized counts 
# 4: name for the heatmap that will be created
# 5: the top number of genes to plot in heatmap (ranked by mean count across all samples)

args<-commandArgs(TRUE)
OUTPUT_DIR<-args[1]
DESIGN_MTX_FILE<-args[2]
NORMALIZED_COUNTS_FILE<-args[3]
HEATMAP_FILE<-args[4]
NUM_GENES<-as.integer(args[5])

# DESIGN_MTX_FILE is created by a python script and has the following columns:
# 1: sample
# 2: count file (full path)
# 3: condition 

#read-in the design matrix 
dm <- read.table(DESIGN_MTX_FILE, header=T, sep='\t')

# merge the count files into a single data frame.
# each row is a gene and each column represents the counts from a particular sample
# each column is named by the sample it corresponds to
# genes that are not common to all the samples are removed via the merge (similar to SQL inner join)
# Count files are most likely in the same order (so could just do cbind(...)), but this step covers all the cases
count<-1
for (i in 1:dim(dm)[1])
{
	sample<-as.character(dm[i,1])
	file<-as.character(dm[i,2])
	data<-read.table(file)
	colnames(data)<-c("gene", sample)
	if(count==1)
	{
		count_data<-data
		count<-count+1
	}
	else
	{	
		count_data<-merge(count_data, data)
	}
}

#name the rows by the genes and remove that column of the dataframe
rownames(count_data)<-count_data[,1]
count_data<-count_data[-1]

#name the rows of the design matrix by the sample names, then remove the first two cols, keeping only condition
rownames(dm)<-dm[,1]
dm<-dm[-1:-2]

#run the DESeq steps:
cds=newCountDataSet(count_data, dm$condition)
cds=estimateSizeFactors(cds)

#write out the normalized counts:
nc<-counts( cds, normalized=TRUE )
result_file<-paste(OUTPUT_DIR, NORMALIZED_COUNTS_FILE, sep='/')
write.csv(as.data.frame(nc), file=result_file, row.names=TRUE)

#produce a heatmap of the normalized counts, using the variance-stabilizing transformation:
cdsFullBlind<-estimateDispersions(cds, method="blind")
vsdFull<-varianceStabilizingTransformation(cdsFullBlind)

select<-order(rowMeans(nc), decreasing=TRUE)[1:NUM_GENES]
heatmapcols<-colorRampPalette(brewer.pal(9, "GnBu"))(100)

#set the longest dimension of the image:
shortest_dimension<-1200 #pixels
sample_count<-ncol(vsdFull)
ratio<-0.25*NUM_GENES/sample_count

#most of the time there will be more genes than samples
#set the aspect ratio of the heatmap accordingly
h<-shortest_dimension*ratio
w<-shortest_dimension

#however, if more samples than genes, switch the dimensions:
if (ratio < 1)
{
	temp<-w
	w<-h
	h<-temp
}

text_size = 1.5+1/log10(NUM_GENES)

#write the heatmap as a png:
png(filename=paste(OUTPUT_DIR,HEATMAP_FILE, sep="/"), width=w, height=h, units="px")
heatmap.2(exprs(vsdFull)[select,], col=heatmapcols, trace="none", margin=c(12,12), cexRow=text_size, cexCol=text_size)
dev.off()

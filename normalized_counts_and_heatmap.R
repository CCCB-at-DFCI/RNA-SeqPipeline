#libraries for this script:
if(!require("DESeq", character.only=T)) stop("Please install the DESeq package first.")

#get args from the commandline:
# 1: full path to the design matrix file
# 2: path for the file where we will write the normalized counts 

args<-commandArgs(TRUE)
DESIGN_MTX_FILE<-args[1]
NORMALIZED_COUNTS_FILE<-args[2]

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
write.csv(as.data.frame(nc), file=NORMALIZED_COUNTS_FILE, row.names=TRUE)

if(!require("DESeq", character.only=T)) stop("Please install the DESeq package first.")

#get args from the commandline:
# 1: full path to the directory to place result files
# 2: design matrix file (full path)
# 3: an identifying string for the output file
# 4: the condition to be compared TO-- e.g. the control condition
# 5: the contrasting condition -- the experimental/case condition
args<-commandArgs(TRUE)
OUTPUT_DIR<-args[1]
DESIGN_MTX_FILE<-args[2]
DESEQ_OUTPUT_IDENTIFIER<-args[3]
CONDITION_A<-args[4]
CONDITION_B<-args[5]

# DESIGN_MTX_FILE is created by a python script and has the following columns:
# 1: sample
# 2: count file (full path)
# 3: condition 

#read-in the design matrix
dm <- read.table(DESIGN_MTX_FILE, header=T, sep='\t')

#filter out the samples we don't need (only comparing the specified conditions--keep only those)
dm <- dm[dm$condition %in% c(CONDITION_A, CONDITION_B),]

# merge the count files into a single data frame.
# each row is a gene and each column represents the counts from a particular sample
# each column is named by the sample it corresponds to
# genes that are not common to all the samples are removed via the merge (similar to SQL inner join)
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

#name the rows of the design matrix by the sample names, then remove the first two cols
rownames(dm)<-dm[,1]
dm<-dm[-1:-2]

#reset the condition column to only be a factor of the current contrast
dm$condition<-factor(dm$condition)

#run the DESeq steps:
cds=newCountDataSet(count_data, dm$condition)
cds=estimateSizeFactors(cds)
cds=estimateDispersions(cds)
res=nbinomTest(cds, CONDITION_A, CONDITION_B)

#write the differential expression results to a file:
file_id<-paste(CONDITION_B, "vs", CONDITION_A, sep="_")
basefile_id<-paste(file_id, DESEQ_OUTPUT_IDENTIFIER,".csv", sep='')
result_file<-paste(OUTPUT_DIR, basefile_id, sep='/')
write.csv(as.data.frame(res), file=result_file, row.names=FALSE)


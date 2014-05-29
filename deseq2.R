sink(file='/dev/null')
if(!require("DESeq2", character.only=T)) stop("Please install the DESeq2 package first.")

#get args from the commandline:
args<-commandArgs(TRUE)
DESIGN_MTX_FILE<-args[1]
CONDITION_A<-args[2]
CONDITION_B<-args[3]

# DESIGN_MTX_FILE is created by a python script and has the following columns:
# 1: sample
# 2: file (just a name, NOT a full path)
# 3: condition 

#get the project dir (this is where we will place the output files)
project_dir<-dirname(DESIGN_MTX_FILE)

#read-in the design matrix, name the rows/samples, and keep only the 
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

rownames(count_data)<-count_data[,1]
count_data<-count_data[-1]

rownames(dm)<-dm[,1]
dm<-dm[-1:-2]

dm$condition<-factor(dm$condition)

ddsHTSeq <- DESeqDataSetFromMatrix(countData=count_data, 
				   colData= dm,
				   design=~condition)

#reorder the $condition factor (by default it orders lexicographically)
ddsHTSeq$condition <- factor(ddsHTSeq$condition, levels=c(CONDITION_A, CONDITION_B))

dds <- DESeq(ddsHTSeq)

res <- results(dds)

dim(res)

ordered_results <- res[order(-res$log2FoldChange),]

dim(ordered_results)

na_filtered_results<- na.omit(ordered_results)

threshold=1.2
filtered_results<-na_filtered_results[abs(na_filtered_results$log2FoldChange)>threshold,]

dim(filtered_results)
sink()

filename<-paste(CONDITION_B, "vs", CONDITION_A, "filtered", threshold, sep="_")
filename<-paste(filename, ".csv", sep='')
filename<-paste(project_dir, filename, sep='/')
write.csv(as.data.frame(filtered_results), file=filename)

filename<-paste(CONDITION_B, "vs", CONDITION_A, sep="_")
filename<-paste(filename, ".csv", sep='')
filename<-paste(project_dir, filename, sep='/')
write.csv(as.data.frame(ordered_results), file=filename)


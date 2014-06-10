## This script parses the raw count files produced by subread, etc.
## Only takes the gene ids and counts from each line-- removes the quotes 
## from the gene id, which is something that is not as straightforward with a tool like 'cut'

args<-commandArgs(TRUE)
in_file<-args[1]
out_file<-args[2]

GENE_ID_COL<-1
COUNT_COL<-7

if (file.exists(in_file))
{
	data<-read.table(in_file, header=TRUE, sep='\t')
	write.table(data[,c(GENE_ID_COL, COUNT_COL)], 
			file=out_file, 
			sep='\t', 
			quote=FALSE,
			row.names=FALSE, 
			col.names=FALSE)

}else
{
	stop(paste("Could not find file ", in_file, " in processing the count files.", sep=''))
}

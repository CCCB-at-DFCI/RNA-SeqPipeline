#this file reads in the count matrix file and produces a .gct file for use with GSEA

args<-commandArgs(TRUE)
original.file<-args[1]
sample.file<-args[2]
gct.file<-args[3]

samples.and.classes<-read.table(sample.file, header=F, sep='\t', stringsAsFactors=F)
samples.and.classes<-samples.and.classes[order(samples.and.classes[,2], samples.and.classes[,1]),]


count.mtx<-read.csv(original.file, sep=',', header=T)

#for ease, split the data:
gene.col<-count.mtx[,1]
count.cols<-count.mtx[,2:ncol(count.mtx)]


#can remove the original object
rm(count.mtx)

#sort the samples by their names- this way they match the .cls file
count.cols<-count.cols[, samples.and.classes[,1]]

#create the proper format for the dataframe to print:
count.mtx<-cbind(gene=gene.col, Description=NA, count.cols)

#write the required header lines:
cat('#1.2', file=gct.file, sep='\n')
cat(paste(nrow(count.mtx), ncol(count.mtx)-2,sep='\t'), file=gct.file, sep='\n', append=T)
write.table(count.mtx, file=gct.file, quote=F, col.names=T, row.names=F, sep='\t', append=T)


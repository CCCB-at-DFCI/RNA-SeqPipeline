#This script writes the .cls file to label the classes (e.g. phenotypes, etc) used in the GSEA analysis

args<-commandArgs(T)
sample.file<-args[1]
cls.file<-args[2]

data<-read.table(sample.file, sep='\t', header=F)

#sort by the second and then first column
data<-data[order(data[,2], data[,1]),]

data[,2]<-factor(data[,2], levels=unique(data[,2]))

#get the number of classes/groups in the dataset
num.classes<-length(levels(data[,2]))

#get the number of samples in the dataset:
num.samples<-length(levels(data[,1]))

#write header lines:
cat(paste(num.samples, num.classes, '1', sep='\t'), file=cls.file, sep='\n')
cat('#\t', file=cls.file, append=T)
write.table(t(levels(data[,2])), file=cls.file, sep='\t', append=T, row.names=F, col.names=F, quote=F)
write.table(t(as.character(data[,2])), sep='\t', file=cls.file, append=T, row.names=F, col.names=F, quote=F)



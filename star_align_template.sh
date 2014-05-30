#!/bin/bash

if ! which STAR ; then
	echo "Could not find STAR aligner in your PATH"
	exit 1
fi

if ! which samtools ; then
	echo "Could not find samtools in your PATH"
	exit 1
fi

GTF=%GTF%
GENOME_INDEX=%GENOME_INDEX% 
BAM_FILE_SUFFIX=%BAM_FILE_SUFFIX%
#############################################################
#input variables (which will be "injected" from elsewhere)
#all paths should be absolute-- no assumptions about where
#alignments should be placed relative to the working directory

SAMPLE_DIR="%SAMPLE_DIR%"
FASTQFILEA="%FASTQFILEA%"
FASTQFILEB="%FASTQFILEB%"
SAMPLE_NAME="%SAMPLE_NAME%"
ASSEMBLY="%ASSEMBLY%"
PAIRED=%PAIRED%
NUM0=0
NUM1=1
OUTDIR=%OUTPUTDIRECTORY%
#############################################################

#create the output directory for the BAM files, etc.:
mkdir $OUTDIR

if [ ! -d "$OUTDIR" ]; then
    echo "Could not create the output directory (permissions?).  Exiting"
    exit 1
fi

#############################################################
#Report some parameters before starting:
echo Working files and variables are':'
echo Sample Directory is $SAMPLE_DIR
echo Sample Name is $SAMPLE_NAME
if [ $PAIRED -eq $NUM1 ]; then
    echo Paired-end sequencing specified. 
    echo Read 1 fastq file: $FASTQFILEA 
    echo Read 2 fastq file: $FASTQFILEB 
else
    echo Single-end sequencing specified. 
    echo Read 1 fastq file: $FASTQFILEA 
fi
echo The Assembly is $ASSEMBLY
echo Output will be placed in $OUTDIR
echo 'GTF file used is '$GTF
echo 'STAR Genome Index used is located at '$GENOME_INDEX 
date

#############################################################
#Run alignments with SNAPR
if [ $PAIRED -eq $NUM0 ]; then
    echo "run single-end alignment for " $SAMPLE_NAME
    STAR --genomeDir $GENOME_INDEX \
         --readFilesIn $FASTQFILEA \
         --runThreadN 4 \
         --readFilesCommand zcat \
         --genomeLoad NoSharedMemory \
         --sjdbGTFfile $GTF \
         --outFileNamePrefix $OUTDIR'/'$SAMPLE_NAME'.'
elif [ $PAIRED -eq $NUM1 ]; then
    echo "run paired alignement for " $SAMPLE_NAME
    STAR --genomeDir $GENOME_INDEX \
         --readFilesIn $FASTQFILEA $FASTQFILEB \
         --runThreadN 4 \
         --readFilesCommand zcat \
         --genomeLoad NoSharedMemory \
         --sjdbGTFfile $GTF \
         --outFileNamePrefix $OUTDIR'/'$SAMPLE_NAME'.'
else
    echo "Did not specify single- or paired-end option."
    exit 1
fi
#############################################################

#for convenience:
BASE=$OUTDIR'/'$SAMPLE_NAME
DEFAULT_SAM=$BASE'.Aligned.out.sam'  #default naming scheme by STAR
SORTED_SAM=$BASE'.sam'
UNSORTED_BAM=$BASE'.bam'
SORTED_BAM=$BASE'.sort' # no .bam-- that is appended by default

#read-group info parsed from sample metadata:
FCID=%FCID%
LANE=%LANE%
INDEX=%INDEX%

#add read-group lines.  Without this, the RNA-SeQC step breaks
java -Xmx4g -jar /cccbstore-rc/projects/cccb/apps/picard-tools-1.42/AddOrReplaceReadGroups.jar \
	  I=$DEFAULT_SAM \
	  o=$SORTED_SAM \
	  VALIDATION_STRINGENCY=LENIENT \
	  TMP_DIR=$OUTDIR/tmp \
	  SORT_ORDER=coordinate \
	  RGID= $FCID'.Lane'$LANE \
	  RGLB=$SAMPLE_NAME \
	  RGPL=illumina \
	  RGPU=$INDEX \
	  RGSM=$SAMPLE_NAME \
	  RGCN='CCCB'

#convert to BAM
samtools view -bS -o $UNSORTED_BAM $SORTED_SAM

#sort
samtools sort -m 1000000000 $UNSORTED_BAM $SORTED_BAM

#rename, so that it will be properly referenced by other scripts:
mv $SORTED_BAM'.bam' $BASE$BAM_FILE_SUFFIX

#create BAM index
samtools index $BASE$BAM_FILE_SUFFIX

#cleanup
#remove the sorted SAM (w/ read groups added), the original SAM produced by STAR, and the unsorted bam
rm $UNSORTED_BAM &
rm $DEFAULT_SAM &
rm $SORTED_SAM &

#remove the empty tmp directories that STAR did not cleanup
rmdir $BASE'._tmp'
rmdir $OUTDIR'/tmp'

chmod 744 $OUTDIR

date

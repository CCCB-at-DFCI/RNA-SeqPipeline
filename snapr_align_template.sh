#!/bin/bash

if ! which snapr ; then
	echo "Could not find snapr aligner in your PATH"
	exit 1
fi


GTF=%GTF%
SNAPR_GENOME_INDEX=%GENOME_INDEX% 
SNAPR_TRANSCRIPTOME_INDEX=%TRANSCRIPTOME_INDEX%
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
echo 'SNAPR Genome Index used is '$SNAPR_GENOME_INDEX 
echo 'SNAPR Transcriptome Index used is '$SNAPR_TRANSCRIPTOME_INDEX
date

#############################################################
#Run alignments with SNAPR
if [ $PAIRED -eq $NUM0 ]; then
    echo "run single alignment for " $SAMPLE_NAME
    snapr single $SNAPR_GENOME_INDEX $SNAPR_TRANSCRIPTOME_INDEX $GTF $FASTQFILEA -o $OUTDIR/$SAMPLE_NAME$BAM_FILE_SUFFIX -M -so
elif [ $PAIRED -eq $NUM1 ]; then
    echo "run paired alignement for " $SAMPLE_NAME
    snapr paired $SNAPR_GENOME_INDEX $SNAPR_TRANSCRIPTOME_INDEX $GTF $FASTQFILEA $FASTQFILEB -o $OUTDIR/$SAMPLE_NAME$BAM_FILE_SUFFIX -M -so
else
    echo "Did not specify single- or paired-end option."
    exit 1
fi
#############################################################

chmod 744 $OUTDIR

date

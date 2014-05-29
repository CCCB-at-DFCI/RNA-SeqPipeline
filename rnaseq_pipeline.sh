#!/bin/bash

echo "
 #==========================================================================#
 #     ______________________     ____  _   _____        _____              #
 #    / ____/ ____/ ____/ __ )   / __ \/ | / /   |	/ ___/___  ____     #
 #   / /   / /   / /   / __  |  / /_/ /  |/ / /| |______\__ \/ _ \/ __ \    #
 #  / /___/ /___/ /___/ /_/ /  / _, _/ /|  / ___ /_____/__/ /  __/ /_/ /    #
 #  \____/\____/\____/_____/  /_/ |_/_/ |_/_/  |_|    /____/\___/\__, /     #
 #                                                                 /_/      #
 #                                                                          #
 #==========================================================================#
"

##########################################################

# initialize some variables:

echo "Checking dependencies..."

#check for java
if ! which java ; then
	echo "Could not find java in current directory or in PATH"
	exit 1
fi

#check for Rscript
if ! which Rscript ; then
	echo "Could not locate the Rscript engine in current directory or PATH"
	exit 1
fi

PYTHON='/cccbstore-rc/projects/cccb/apps/bin/python2.7'
#check for python- for regex syntax need 2.7 or greater!
if ! which $PYTHON ; then
	echo "Could not access python located at $PYTHON.  Require version 2.7 or greater"
	exit 1
fi

######################################################################################
#Defining the location of the pipeline and some related scripts

#the 'home' directory for the RNA-seq pipeline:
PIPELINE_HOME="/cccbstore-rc/projects/cccb/pipelines/RNA_Seq_pipeline"

#a directory containing the template files+libraries for creating the output report. will be filled-in by scripts at end of pipeline
REPORT_TEMPLATE_DIR=$PIPELINE_HOME"/report_generator" #somewhere centrally located (do not change)
REPORT_TEMPLATE_LIBRARIES=$REPORT_TEMPLATE_DIR'/lib/'
REPORT_TEMPLATE_HTML=$REPORT_TEMPLATE_DIR'/rnaseq_template.html'
ERROR_PAGE=$REPORT_TEMPLATE_DIR'/error.html'

# the location of the template alignment scripts:
SNAPR_ALIGN_SCRIPT=$PIPELINE_HOME"/snapr_align_template.sh"
STAR_ALIGN_SCRIPT=$PIPELINE_HOME"/star_align_template.sh"

#some helper scripts:
PREPARE_ALIGN_SCRIPT=$PIPELINE_HOME'/prepare_align_script.py'
CHECK_BAM_SCRIPT=$PIPELINE_HOME'/check_for_bam.py'
CREATE_DESIGN_MATRIX_SCRIPT=$PIPELINE_HOME'/create_design_matrix.py'
CREATE_REPORT_SCRIPT=$REPORT_TEMPLATE_DIR'/create_report.py'

# R script for calling DESeq and performing the differential expression analysis:
DESEQ_SCRIPT=$PIPELINE_HOME"/deseq_original.R"

#the R script for calling DESeq to get the normalized counts (and also produce a heatmap):
NORMALIZED_COUNTS_SCRIPT=$PIPELINE_HOME"/normalized_counts_and_heatmap.R"

# add samtools to PATH
export PATH=/cccbstore-rc/projects/cccb/apps/samtools-0.1.19/:$PATH
if ! which samtools ; then
	echo "Could not locate samtools in current directory or PATH: "$PATH 
	exit 1
fi


# add subread to PATH
export PATH=/cccbstore-rc/projects/cccb/apps/subread-1.4.4-Linux-x86_64/bin/:$PATH
if ! which featureCounts ; then
	echo "Could not locate Subreads's featureCounts utility in current directory or PATH: "$PATH 
	exit 1
fi

#####################################################################################

#####################################################################################
# definitions related to the STAR aligner:

#a string for the star aligner-- for consistent referral
STAR="STAR"

STAR_LOCATION=/cccbstore-rc/projects/cccb/apps/STAR_2.3.1z4/
export PATH=$STAR_LOCATION:$PATH

#####################################################################################


#####################################################################################
# definitions related to the SNAPR aligner:

#add snapR to the PATH:
SNAPR_LOCATION=/cccbstore-rc/projects/cccb/apps/snapr-master/
export PATH=$SNAPR_LOCATION:$PATH

#a string for the snapr aligner-- for consistent referral
SNAPR="SNAPR"

#how long to sleep (in seconds) in between attempts to run snapr (in the case that another snapr process is already running we do NOT want to start another!)
SLEEP_TIME=300

#the maximum times to try and run snapr (in case of another snapr process running, we sleep and wait this many times)
MAX_ALIGN_ATTEMPTS=20

#used for identifying if there are other snapr processes currently running.  When pgrep is run, searching for "snapr" will flag them
#thus, this should be what shows up if you run 'top'
SNAPR_PROCESS="snapr"

# a file extension for the count files.  
# for example, sample SH10_XXX would have count file SH10_XXX.counts if this variable is '.counts'
COUNTFILE_SUFFIX=".gene_name.counts.txt"
#####################################################################################################


#####################################################################################################
#Definitions related to the RNA-SeQC process:

#location of RNA_seQC jar:
RNA_SEQC_JAR=$PIPELINE_HOME"/RNA-SeQC_v1.1.7.jar"

#name of the default html report generated by RNA-seQC-- this will be nested in our output html report
DEFAULT_RNA_SEQC_REPORT='report.html'
#####################################################################################################



#####################################################################################################
#some other configuration parameters-- most are "arbitrary" and can be left as-is.

#the name (not path) of	the sample sheet (containing sequencing	metadata) located in the sample-specific directories:
SAMPLE_SHEET_NAME='SampleSheet.csv'

# the prefix for the sample-specific directories (often 'Sample_').
# Depending on the process producing the project directories + FASTQ files, this could change.
SAMPLE_DIR_PREFIX="Sample_"

# a file suffix/extension for identifying the alignment scripts that are generated on-the-fly by a python script
FORMATTED_ALIGN_SCRIPT_NAMETAG="_aln.sh"

#  the name for the directory where the alignments will output files.  This will be inside of the sample-specific directory 
ALN_DIR_NAME=

# the desired output extension for the sorted bam files
SORTED_TAG=".sorted"
BAM_EXTENSION=".bam"

#DESeq output directory- to be placed in PROJECT_DIR
DESEQ_RESULT_DIR="deseq_results"

#a string that will make identification of DESeq output easier:
DESEQ_OUTFILE_TAG=".deseq"

#a normalized counts file for all the samples, produced by DESEQ:
NORMALIZED_COUNTS_FILE="normalized_counts.csv"

# the heatmap filename
HEATMAP_FILE="heatmap.png"

# the number of genes to include in the heatmap
# (the top X number of genes ranked by average counts across all samples)
HEATMAP_GENE_COUNT=30

# a directory (to be placed in $PROJECT_DIR) where the count files will be located
COUNTS_DIR="count_files"

#a directory for the overall report html and and associated files- located in the project directory
REPORT_DIR="output_report"

#the name of the final html report produced by the pipeline.  To be placed in the REPORT_DIR
FINAL_RESULTS_REPORT='results_report.html'

#a directory where the RNA-seQC will write-- located in the REPORT_DIR directory
RNA_SEQC_DIR="rna_seQC_reports"

#  the name of a temporary file which will keep track of all valid samples (based on the presence of data, etc)
VALID_SAMPLE_FILE="valid_samples.txt"

# The name for the design matrix file that will be given to DESeq.  Placed in $PROJECT_DIR
DESIGN_MTX_FILE="design_mtx.txt"

############################################################################################################
# some default parameters

#default aligner
ALIGNER="STAR"

# default genome-- user may specify other in commandline args
ASSEMBLY="hg19"

# default flag for whether to perform alignment (0=no, 1=yes).  User may specify in commandline args
ALN=1

# default flag for whether the protocol was paired or single end (0=single end, 1=paired).  User may specify in commandline args
PAIRED_READS=0

# Initialize empty variables-- these are required args to the script and are validated below
CONTRAST_FILE=
SAMPLES_FILE=
PROJECT_DIR=

# default flag for running the debug/test-- skips the long-running processes to test the main workflow
TEST=0

# some convenience variables
NUM1=1
NUM0=0
############################################################################################################


#  a function that prints the proper usage syntax
function usage
{
	echo "**************************************************************************************************"
	echo "usage: 
		-d | --dir sample_directory 
		-s | --samples samples_file 
		-c | --contrasts contrast_file (optional) 
                -noalign (optional, default behavior is to align) 
                -paired (optional, default= single-end) 
		-g | --genome (optional, default is hg19)
		-a | --aligner (optional, default is STAR)
		-test (optional, for simple test)"
	echo "**************************************************************************************************"
}


#  expects the following args:
#  $1: a file containing the sample and condition (tab-separated) (one per line)
function print_sample_report
{
	if [ -e $1 ]; then
		echo ""
		printf "%s\t%s\n" Sample Condition
		 while read line; do
			printf "%s\t%s\n" $(echo $line | awk '{print $1}') $(echo $line | awk '{print $2}')
		done < $1
		echo ""
		echo ""
	else
		echo "Sample file ("$1") was not found."
	fi
}


#  expects the following args:
#  $1: a file containing the base/control and experimental/case condition (tab-separated) (one per line)
function print_contrast_report
{
	if [ -e $1 ]; then
		echo ""
		printf "%s\t%s\n" Base/Control Case/Condition
	        while read line; do
			printf "%s\t%s\n" $(echo $line | awk '{print $1}') $(echo $line | awk '{print $2}')
		done < $1
		echo ""
		echo ""
	else
		echo "Contrast file ("$1") was not found."
	fi
}



##########################################################

#read input from commandline:
while [ "$1" != "" ]; do
	case $1 in
		-c | --contrasts )
			shift
			CONTRAST_FILE=$1
			;;
		-d | --dir )
			shift
			PROJECT_DIR=$1
			;;
		-g | --genome )
			shift
			ASSEMBLY=$1
			;;
		-s | --samples )
			shift
			SAMPLES_FILE=$1
			;;
		-a | --aligner )
			shift
			ALIGNER=$1
			;;
		-noalign )
			ALN=0
			;;
		-paired )
			PAIRED_READS=1
			;;
		-h | --help )
			usage
			exit
			;;
		-test )
			TEST=1
			;;
		* )
			usage
			exit 1
	esac
	shift
done

############################################################





############################################################

#check that we have all the required input:

if [ "$PROJECT_DIR" == "" ]; then
    echo ""
    echo "ERROR: Missing the project directory.  Please try again."
    usage
    exit 1
fi

if [ "$SAMPLES_FILE" == "" ]; then
    echo ""
    echo "ERROR: Missing the samples file.  Please try again."
    usage
    exit 1
fi

############################################################




############################################################
# After inputs have been read, proceed with setting up parameters based on these inputs:

# construct the full paths to some files by prepending the project directory:
VALID_SAMPLE_FILE=$PROJECT_DIR'/'$VALID_SAMPLE_FILE
DESIGN_MTX_FILE=$PROJECT_DIR'/'$DESIGN_MTX_FILE
COUNTS_DIR=$PROJECT_DIR'/'$COUNTS_DIR


#############################################################

#identify the correct genome files to use
if [[ "$ASSEMBLY" == hg19 ]]; then
    GTF=/cccbstore-rc/projects/db/genomes/Human/GRCh37.75/GTF/Homo_sapiens.GRCh37.75.gtf
    GENOMEFASTA=/cccbstore-rc/projects/db/genomes/Human/GRCh37.75/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa
    SNAPR_GENOME_INDEX=/cccbstore-rc/projects/db/genomes/Human/GRCh37.75/SNAPR/index-dir
    SNAPR_TRANSCRIPTOME_INDEX=/cccbstore-rc/projects/db/genomes/Human/GRCh37.75/SNAPR/transcriptome-dir
    STAR_GENOME_INDEX=/cccbstore-rc/projects/db/genomes/Human/GRCh37.75/STAR_INDEX  
    GTF_FOR_RNASEQC=/cccbstore-rc/projects/db/genomes/Human/GRCh37.75/GTF/Homo_sapiens.GRCh37.75.transcript_id.chr_trimmed.gtf
elif [[ "$ASSEMBLY" == mm10 ]]; then
    GTF=/cccbstore-rc/projects/db/genomes/Mm/build38/Mus_musculus.GRCm38.75.chr_trimmed.gtf
    GENOMEFASTA=/cccbstore-rc/projects/db/genomes/Mm/build38/mm10.fa
    SNAPR_GENOME_INDEX=/cccbstore-rc/projects/db/genomes/Mm/build38/snapr_genome_index
    SNAPR_TRANSCRIPTOME_INDEX=/cccbstore-rc/projects/db/genomes/Mm/build38/snapr_transcriptome_index
    STAR_GENOME_INDEX=/cccbstore-rc/projects/db/genomes/Mm/build38/STAR_INDEX
    GTF_FOR_RNASEQC=/cccbstore-rc/projects/db/genomes/Mm/build38/Mus_musculus.GRCm38.75.transcript_id.chr_trimmed.gtf
else
    echo "Unknown or un-indexed genome."
    exit 1
fi

#############################################################

# parameters based on the aligner selected:
if [[ $ALIGNER == $STAR  ]]; then
    ALN_DIR_NAME="star_out"
    ALIGN_SCRIPT=$STAR_ALIGN_SCRIPT
    GENOME_INDEX=$STAR_GENOME_INDEX
    TRANSCRIPTOME_INDEX=    #nothing
elif [[ $ALIGNER == $SNAPR ]]; then
    ALN_DIR_NAME="snapr_out"
    ALIGN_SCRIPT=$SNAPR_ALIGN_SCRIPT
    GENOME_INDEX=$SNAPR_GENOME_INDEX
    TRANSCRIPTOME_INDEX=$SNAPR_TRANSCRIPTOME_INDEX    
else
    echo ""
    echo "ERROR: Unrecognized aligner.  Exiting"
    exit 1
fi

############################################################

############################################################

#print out the parameters for logging:

echo ""
echo "Will attempt to perform analysis on samples (from "$SAMPLES_FILE"):"
print_sample_report $SAMPLES_FILE
echo ""
if [ "$CONTRAST_FILE" == "" ]; then
	echo "Will NOT perform differential analysis since no contrast file supplied."
else
	echo "Will attempt to perform the following contrasts (from "$CONTRAST_FILE"):"
	print_contrast_report $CONTRAST_FILE
fi
echo ""
echo "Project home directory: "$PROJECT_DIR
if [ $ALN -eq $NUM1 ]; then
	echo "Perform alignment with "$ALIGNER
	echo "Alignment will be performed against: "$ASSEMBLY
fi
echo ""
echo ""

############################################################


############################################################
#check if alignment is needed
# if yes, perform alignment

if [ $ALN -eq $NUM1 ]; then

    #call a python script that scans the sample directory, checks for the correct files,
    # and injects the proper parameters into the alignment shell script

    $PYTHON $PREPARE_ALIGN_SCRIPT \
            $SAMPLES_FILE \
            $PROJECT_DIR \
            $ALN_DIR_NAME \
            $SAMPLE_SHEET_NAME \
            $PAIRED_READS \
            $ASSEMBLY \
            $VALID_SAMPLE_FILE \
            $ALIGN_SCRIPT \
            $FORMATTED_ALIGN_SCRIPT_NAMETAG \
            $SAMPLE_DIR_PREFIX \
            $GTF \
            $GENOME_INDEX \
            $ALIGNER \
            $SORTED_TAG$BAM_EXTENSION \
            $TRANSCRIPTOME_INDEX || { echo "Something went wrong in preparing the alignment scripts.  Exiting."; exit 1; }

    echo "After examining project structure, will attempt to align on the following samples:"
    print_sample_report $VALID_SAMPLE_FILE

    #given the valid samples (determined by the python script), run the alignment
    # note that this is NOT done in parallel!  SNAPR and STAR are VERY memory intensive

    for sample in $( cut -f1 $VALID_SAMPLE_FILE ); do
		FLAG=0
		while [ $FLAG -eq 0 ]; do
			#check if other SNAPR or STAR processes are running first:
			if [ "$(pgrep $SNAPR_PROCESS)" == "" ] && [ "$(pgrep $STAR)" == "" ]; then
			        echo "Run alignment with script at: "
				echo $PROJECT_DIR'/'$SAMPLE_DIR_PREFIX$sample'/'$sample$FORMATTED_ALIGN_SCRIPT_NAMETAG   
				date
				echo ""
                                chmod a+x $PROJECT_DIR'/'$SAMPLE_DIR_PREFIX$sample'/'$sample$FORMATTED_ALIGN_SCRIPT_NAMETAG
				
				#kickoff the script and wait until completion:
			        if [ $TEST -eq $NUM0 ]; then
					$PROJECT_DIR'/'$SAMPLE_DIR_PREFIX$sample'/'$sample$FORMATTED_ALIGN_SCRIPT_NAMETAG                
				else
					echo "...[Mock alignment]..."
					mkdir $PROJECT_DIR'/'$SAMPLE_DIR_PREFIX$sample'/'$ALN_DIR_NAME
					touch $PROJECT_DIR'/'$SAMPLE_DIR_PREFIX$sample'/'$ALN_DIR_NAME'/'$sample$SORTED_TAG$BAM_EXTENSION
				fi
				echo "Alignment on sample $sample completed at: "
				date
				FLAG=1
			else
				if [ $ATTEMPTS < $MAX_ALIGN_ATTEMPTS ]; then
					echo "Another snapr or star process is running.  Will sleep for $SLEEP_TIME seconds and try again. (Max attempts=$MAX_ALIGN_ATTEMPTS)"
					sleep $SLEEP_TIME
					let ATTEMPTS+=1
				else
					echo "Reached the maximum amount of attempts.  Exiting with task incomplete."
					exit 1
				fi
			fi
		done
	
    done

else

    echo "Skipping alignment based on input parameters (-noalign).  Locating BAM files..."
   
    #since we did not align here using STAR, etc., change the ALN_DIR_NAME to something generic:
    ALN_DIR_NAME="bam_file"

    #given bam files contained anywhere in PROJECT_HOME, construct the assumed project
    #hierarchy and create symbolic links to the bam files

    while read line; do
    	SAMPLE=$(echo $line | awk '{print $1}')

	#the name of the link (in our convention) which will link to the original bam file
	BASE_BAM_FILE=$SAMPLE$SORTED_TAG$BAM_EXTENSION
	BAM_FILE=$(find -L $PROJECT_DIR -type f -name $SAMPLE*$BAM_EXTENSION)
	if [ "$BAM_FILE" != "" ]; then
		SAMPLE_ALN_DIR=$PROJECT_DIR'/'$SAMPLE_DIR_PREFIX$SAMPLE'/'$ALN_DIR_NAME
		mkdir -p $SAMPLE_ALN_DIR
		ln -s $BAM_FILE $SAMPLE_ALN_DIR'/'$BASE_BAM_FILE
#		echo $line >> $VALID_SAMPLE_FILE
		printf "%s\t%s\n" $(echo $SAMPLE) $(echo $line | awk '{print $2}') >> $VALID_SAMPLE_FILE
	else
		echo "Could not locate a properly named BAM file for sample "$SAMPLE
	fi
    done < $SAMPLES_FILE

    echo "Found BAM files for the following samples:"
    print_sample_report $VALID_SAMPLE_FILE
    
fi


############################################################

# check for the appropriate bam files and update the valid sample file accordingly:
$PYTHON $CHECK_BAM_SCRIPT $VALID_SAMPLE_FILE $PROJECT_DIR $SAMPLE_DIR_PREFIX $ALN_DIR_NAME $SORTED_TAG$BAM_EXTENSION

############################################################

############################################################
# create or move the count files to prepare for differential analysis:

mkdir -p $COUNTS_DIR

if [ ! -d "$COUNTS_DIR" ]; then
    echo "Could not create the count directory (permissions?).  Exiting"
    exit 1
fi

if [ $TEST -eq $NUM0 ]; then


	if [[ $ALIGNER == $STAR  ]]; then

    		#create the count files from the BAM files
    		for sample in $( cut -f1 $VALID_SAMPLE_FILE ); do
    		    featureCounts -a $GTF \
				  -o $COUNTS_DIR'/'$sample$COUNTFILE_SUFFIX \
				  -t exon \
				  -g gene_name $PROJECT_DIR"/"$SAMPLE_DIR_PREFIX$sample"/"$ALN_DIR_NAME"/"$sample$SORTED_TAG$BAM_EXTENSION
    		done
	elif [[ $ALIGNER == $SNAPR ]]; then
	    #move the count files
	    for sample in $( cut -f1 $VALID_SAMPLE_FILE ); do
	    	mv $PROJECT_DIR'/'$SAMPLE_DIR_PREFIX$sample'/'$ALN_DIR_NAME'/'$sample$SORTED_TAG$COUNTFILE_SUFFIX $COUNTS_DIR'/'$sample$COUNTFILE_SUFFIX        
            done
	fi

#if test case (create dummy files in counts directory):
else 
	for sample in $( cut -f1 $VALID_SAMPLE_FILE ); do
		touch $COUNTS_DIR'/'$sample$COUNTFILE_SUFFIX
	done
fi

#with the count files moved, create a design matrix for DESeq:
$PYTHON $CREATE_DESIGN_MATRIX_SCRIPT $VALID_SAMPLE_FILE $DESIGN_MTX_FILE $PROJECT_DIR $COUNTS_DIR $COUNTFILE_SUFFIX

############################################################


############################################################

#create a report directory to hold the report and the output analysis:
REPORT_DIR=$PROJECT_DIR'/'$REPORT_DIR
mkdir $REPORT_DIR

############################################################



############################################################
#get the normalized counts via DESEQ:

#first create an output directory for the deseq scripts that will be run:
DESEQ_RESULT_DIR=$REPORT_DIR'/'$DESEQ_RESULT_DIR
mkdir $DESEQ_RESULT_DIR

if [ $TEST -eq $NUM0 ]; then
	Rscript $NORMALIZED_COUNTS_SCRIPT $DESEQ_RESULT_DIR $DESIGN_MTX_FILE $NORMALIZED_COUNTS_FILE $HEATMAP_FILE $HEATMAP_GENE_COUNT
else
	echo "Perform mock normalized counts with DESeq."
fi

if [ -e "$CONTRAST_FILE" ]; then
	echo "Run differential expression with DESeq"
	while read contrast; do
    		conditionA=$(echo $contrast | awk '{print $1}')
    		conditionB=$(echo $contrast | awk '{print $2}')

    		if [ $TEST -eq $NUM0 ]; then
    			Rscript $DESEQ_SCRIPT $DESEQ_RESULT_DIR $DESIGN_MTX_FILE $conditionA $conditionB
		else
			echo "Perform mock DESeq step on contrast between "$conditionA "and" $conditionB
    		fi
	done < $CONTRAST_FILE
else
	echo "Skipping differential analysis since no contrast file was specified."
fi
############################################################


############################################################
#Report creation:

#create the reports with RNA-seQC:
while read line; do
 	SAMPLE=$(echo $line | awk '{print $1}')
	SAMPLE_BAM=$PROJECT_DIR'/'$SAMPLE_DIR_PREFIX$SAMPLE'/'$ALN_DIR_NAME'/'$SAMPLE$SORTED_TAG$BAM_EXTENSION

        #create output directory
        SAMPLE_QC_DIR=$REPORT_DIR'/'$RNA_SEQC_DIR'/'$SAMPLE
        mkdir -p $SAMPLE_QC_DIR
 
    	if [ $TEST -eq $NUM0 ]; then
		java -jar $RNA_SEQC_JAR \
		-o $SAMPLE_QC_DIR \
		-r $GENOMEFASTA \
		-s "$SAMPLE|$SAMPLE_BAM|-" \
		-t $GTF_FOR_RNASEQC || { echo "Something failed on performing QC step.  Check the output for guidance."; }
	else
		echo "Perform mock QC analysis, etc. on "$SAMPLE
	fi
done < $VALID_SAMPLE_FILE


#Report creation:

#copy the necessary libraries to go with the html report:
cp -r $REPORT_TEMPLATE_LIBRARIES $REPORT_DIR

#run the injection script to create the report:
if [ $TEST -eq $NUM0 ]; then
	$PYTHON $CREATE_REPORT_SCRIPT $REPORT_TEMPLATE_HTML $REPORT_DIR'/'$FINAL_RESULTS_REPORT $VALID_SAMPLE_FILE $REPORT_DIR'/'$RNA_SEQC_DIR $DEFAULT_RNA_SEQC_REPORT $DESEQ_RESULT_DIR $HEATMAP_FILE $NORMALIZED_COUNTS_FILE $DESEQ_OUTFILE_TAG $ERROR_PAGE
else
	echo "Perform mock creation of output report."
fi
############################################################


############################################################
#cleanup

#rm $VALID_SAMPLE_FILE



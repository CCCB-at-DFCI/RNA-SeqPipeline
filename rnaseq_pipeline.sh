#!/bin/bash


#########################################################################################################################################
#                                                                                                                                       #
#                                                     Some helper/utility functions                                                     #
#                                                                                                                                       #
#########################################################################################################################################


#  a function that prints the proper usage syntax if 'help' or incorrect/incomplete args are used:
function usage
{
        echo "**************************************************************************************************"
        echo "usage:
                -d | --dir <path to sample directory>
                -g | --genome <hg19 | mm10>
                -o | --output <path to output directory- this directory does NOT exist.  The pipeline will create it.>
                -s | --samples <path to samples_file> (optional- if missing, it will infer the samples based on the project directory structure.)
                -c | --contrasts <contrast_file> (optional)
                -config <path to configuration file> (optional, configuration file-- if not given, use default)
                -noalign (optional, default behavior is to align.  This is if you already have BAM files.  )
                -paired (optional, default= single-end)
                -target <string> (optional- if the BAM files already exist and you want to select those with a particular suffix.  Default behavior is to find the newest BAM for each s$
                -no_dedup (optional, default will dedup the BAM files.  Final result is a sorted, primary BAM file)
                -a | --aligner <STAR | SNAPR> (optional, default is STAR)
                -align_only (optional, if generating only BAM, count files, and QC.  Skips differential expression analysis.)
                -test (optional, for simple test)"
        echo "**************************************************************************************************"
}

#  Prints out the sample/condition annotation file.  Expects the following args:
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

#  Prints out the contrasts that we are running into the DGE.  Expects the following args:
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

#########################################################################################################################################
#                                                                                                                                       #
#                                                     Some helper/utility functions (end)                                               #
#                                                                                                                                       #
#########################################################################################################################################

#########################################################################################################################################
#                                                                                                                                       #
#                                                     Read command-line args/input                                                      #
#                                                                                                                                       #
#########################################################################################################################################


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
		-o | --output )
			shift
			TARGET_DIR=$1
			;;
		-s | --samples )
			shift
			SAMPLES_FILE=$1
			;;
                -config )
                        shift
                        CONFIG=$1
                        ;;
		-a | --aligner )
			shift
			ALIGNER=$1
			;;
		-noalign )
			ALN=0
			;;
		-no_dedup )
			DEDUP=0
			;;
		-paired )
			PAIRED_READS=1
			;;
                -target )
                        shift
                        TARGET_BAM=$1
                        ;;
                -align_only )
                        SKIP_ANALYSIS=1
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


#check that we have all the required input:

if [ "$PROJECT_DIR" == "" ]; then
    echo -e "\n\nERROR: Missing the path to the project directory.  Please try again.\n\n"
    usage
    exit 1
fi

if [ "$TARGET_DIR" == "" ]; then
    echo "\n\nERROR: Missing the target directory path argument (where the final analysis will be placed).  Please try again.\n\n"
    usage
    exit 1
fi

if [ "$ASSEMBLY" == "" ]; then
    echo "\n\nERROR: Missing the genome.  Please try again.\n\n"
    usage
    exit 1
fi


# Set some default parameters if they were not explicitly set in the input args:

if [ "$PAIRED_READS" == "" ]; then
    PAIRED_READS=0
fi

#if ALN was not set, then -noalign flag was NOT invoked, meaning we DO align
if [ "$ALN" == "" ]; then
    ALN=1       
fi

#if TEST was not set, then do NOT test
if [ "$TEST" == "" ]; then
    TEST=0
fi

#if SKIP_ANALYSIS was not set, then we DO want to perform analysis, so set the flag to zero
if [ "$SKIP_ANALYSIS" == "" ]; then
    SKIP_ANALYSIS=0
fi

#if the aligner was not explicitly set, default to STAR
if [ "$ALIGNER" == "" ]; then
    ALIGNER=STAR
fi


#if no configuration file was given, then use the default one
if [ "$CONFIG" == "" ]; then
    CONFIG=/cccbstore-rc/projects/cccb/pipelines/RNA-SeqPipeline/config.txt
    # double check that the configuration file exists:
    if [[ ! -f "$CONFIG" ]]; then
        echo "\n\nCould not locate a configuration file at $CONFIG\n\n"
        exit 1
    fi 
fi

#########################################################################################################################################
#                                                                                                                                       #
#                                                     Read command-line args/input (end)                                                #
#                                                                                                                                       #
#########################################################################################################################################


#########################################################################################################################################
#                                                                                                                                       #
#                                                     Final variable setup                                                              #
#                                                                                                                                       #
#########################################################################################################################################


#  read-in the non-dynamic configuration parameters (and export via set to have these as environment variables):
#  !!! important-- import the configuration file !!!
set -a
source $CONFIG
set +a


############# After inputs have been read, proceed with setting up parameters based on these inputs:  #################################

# if DEDUP was not set to zero (using the -no_dedup flag), then set it to 1 for true
# also set the file extension tag for the final BAM file.
if [ "$DEDUP" == "" ]; then
    DEDUP=1
    FINAL_BAM_SUFFIX=$SORTED_DEDUPED_PRIMARY_BAM
else
    FINAL_BAM_SUFFIX=$SORTED_PRIMARY_BAM
fi

# if TARGET_BAM was not set via the commandline arg, set it to the default BAM extension
if [ "$TARGET_BAM" == "" ]; then
    TARGET_BAM=$BAM_EXTENSION       
fi

# if a sample annotation file was not given as an input arg.  Since the samples have not been annotated, we cannot run any diff exp analysis.
if [ "$SAMPLES_FILE" == "" ]; then
    # Set the flag to just align:
    SKIP_ANALYSIS=1 #in case this was not set in the input arguments

    #create a sample annotation file by parsing the directory structure and assigning a dummy group annotation
    SAMPLES_FILE=$PROJECT_DIR/samples.txt
    ls -d $PROJECT_DIR/$SAMPLE_DIR_PREFIX* | sed -e "s/.*$SAMPLE_DIR_PREFIX//g" | sed -e 's/$/\tX/g' >$SAMPLES_FILE
fi


###############  identify the correct genome files to use  ######################################################
if [[ "$ASSEMBLY" == hg19 ]]; then
    GTF=/cccbstore-rc/projects/db/genomes/Human/GRCh37.75/GTF/Homo_sapiens.GRCh37.75.gtf
    GENOMEFASTA=/cccbstore-rc/projects/db/genomes/Human/GRCh37.75/Homo_sapiens.GRCh37.75.dna.primary_assembly.reordered.fa
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

# parameters based on the aligner selected:
if [[ $ALIGNER == $STAR  ]]; then
    ALN_DIR_NAME=$STAR_ALIGN_DIR
    ALIGN_SCRIPT=$STAR_ALIGN_SCRIPT
    GENOME_INDEX=$STAR_GENOME_INDEX
    TRANSCRIPTOME_INDEX=    #nothing
    ALIGNER_REF_URL=STAR_REF_URL
elif [[ $ALIGNER == $SNAPR ]]; then
    ALN_DIR_NAME=$SNAPR_ALIGN_DIR
    ALIGN_SCRIPT=$SNAPR_ALIGN_SCRIPT
    GENOME_INDEX=$SNAPR_GENOME_INDEX
    TRANSCRIPTOME_INDEX=$SNAPR_TRANSCRIPTOME_INDEX    
    ALIGNER_REF_URL=SNAPR_REF_URL
else
    echo -e "\n\nERROR: Unrecognized aligner.  Exiting\n\n"
    exit 1
fi

# construct the full paths to some files by prepending the project directory:
export VALID_SAMPLE_FILE=$PROJECT_DIR'/'$VALID_SAMPLE_FILE
export DESIGN_MTX_FILE=$PROJECT_DIR'/'$DESIGN_MTX_FILE

#create a report directory to hold the report and the output analysis:
export REPORT_DIR=$PROJECT_DIR'/'$REPORT_DIR
mkdir $REPORT_DIR

export COUNTS_DIR=$REPORT_DIR'/'$COUNTS_DIR

# export some additional variables:
export ASSEMBLY
export GTF
export PROJECT_DIR
export PAIRED_READS
export ALIGNER
export SAMPLES_FILE
export CONTRAST_FILE
export TARGET_BAM
export DEDUP
export FINAL_BAM_SUFFIX
export ALN_DIR_NAME
export ALIGN_SCRIPT
export GENOME_INDEX
export TRANSCRIPTOME_INDEX
export ALIGNER_REF_URL
export SKIP_ANALYSIS

#########################################################################################################################################
#                                                                                                                                       #
#                                                     Final variable setup  (end)                                                       #
#                                                                                                                                       #
#########################################################################################################################################


#begin logging:

#default logging file:
LOGFILE=log.txt

#create the target directory where the logfile (and analysis) will be placed
mkdir $TARGET_DIR || { echo -e "\n\nCould not create your target directory (does it already exist? Do you have the proper permissions?).  Try again. Exiting.\n\n"; exit 1; }


#open brace for "logging block"-- everything inside the braces is tee'd into the logfile
{

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


############ Print out some information to stdout ##################################################################

echo -e "\nWill attempt to perform analysis on samples (from "$SAMPLES_FILE"):\n"
print_sample_report $SAMPLES_FILE
if [ "$CONTRAST_FILE" == "" ]; then
	echo -e "\nWill NOT perform differential analysis since no contrast file supplied.\n"
else
	echo -e "\nWill attempt to perform the following contrasts (from "$CONTRAST_FILE"):\n"
	print_contrast_report $CONTRAST_FILE
fi

echo -e "\nProject home directory: $PROJECT_DIR \n"
if [ $ALN -eq $NUM1 ]; then
	echo -e "Perform alignment with $ALIGNER \n"
	echo -e "Alignment will be performed against: $ASSEMBLY \n"
fi

echo -e "\nChecking dependencies:\n"

#check for R dependencies before continuing:
Rscript $R_DEPENDENCY_CHECK_SCRIPT || { echo "The proper R dependencies were not installed or could not be installed.  Check $R_DEPENDENCY_CHECK_SCRIPT to see which packages should be installed in your R instance.  Exiting."; exit 1; }
# initialize some variables:

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


echo "
#########################################################################################################################################
#                                                                                                                                       #
#                                                     Alignment Section                                                                 #
#                                                                                                                                       #
#########################################################################################################################################
"

if [ $ALN -eq $NUM1 ]; then

    #call a python script that scans the sample directory, checks for the correct files,
    # and injects the proper parameters into the alignment shell script
    $PYTHON $PREPARE_ALIGN_SCRIPT || { echo "Something went wrong in preparing the alignment scripts.  Exiting"; exit 1; }


    echo "After examining project structure, will attempt to align on the following samples:"
    print_sample_report $VALID_SAMPLE_FILE

    #given the valid samples (determined by the python script), run the alignment
    # note that this is NOT done in parallel!  SNAPR and STAR are VERY memory intensive

    for sample in $( cut -f1 $VALID_SAMPLE_FILE ); do
		FLAG=0
		ATTEMPTS=0
		#while loop attempts to submit/wait the same job if there happens to be another star/snapr process running
		while [ $FLAG -eq 0 ]; do
			#check if other SNAPR or STAR processes are running first:
			if [ "$(pgrep $SNAPR_PROCESS)" == "" ] && [ "$(pgrep $STAR)" == "" ]; then
				ALN_SCRIPT=$PROJECT_DIR'/'$SAMPLE_DIR_PREFIX$sample'/'$sample$FORMATTED_ALIGN_SCRIPT_NAMETAG
			        chmod a+x $ALN_SCRIPT
      				echo -e "\nRun alignment with script at: $ALN_SCRIPT \n"
				date
				
				#kickoff the script and wait until completion:
			        if [ $TEST -eq $NUM0 ]; then
					$ALN_SCRIPT                
				else
					echo "...[Mock alignment]..."
					mkdir $PROJECT_DIR'/'$SAMPLE_DIR_PREFIX$sample'/'$ALN_DIR_NAME
					touch $PROJECT_DIR'/'$SAMPLE_DIR_PREFIX$sample'/'$ALN_DIR_NAME'/'$sample$FINAL_BAM_SUFFIX
				fi
				echo "Alignment on sample $sample completed at: "
				date
				FLAG=1 #to break out of while loop
			else
				if [ $ATTEMPTS -le $MAX_ALIGN_ATTEMPTS ]; then
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

else  # if did not ask for alignment, find the BAM files that are implied to exist:

    echo -e "\n\nSkipping alignment based on input parameters (-noalign).  Locating BAM files...\n"
   
    #since we did not align here using STAR, etc., change the ALN_DIR_NAME to something generic:
    ALN_DIR_NAME="bam_file"
    export ALN_DIR_NAME

    #given bam files contained anywhere in PROJECT_DIR, construct the assumed project
    #hierarchy and create symbolic links to the bam files

    while read line; do
    	SAMPLE=$(echo $line | awk '{print $1}')

	#the name of the link (in our convention) which will link to the original bam file
	FINAL_BAM_FILE=$SAMPLE$FINAL_BAM_SUFFIX
	
	#find bam files that begin with the sample name and end with the proper extension.  There may be >1, so we have to watch for that.
	ALL_BAM_FILES=( $( find -L $PROJECT_DIR -type f -name $SAMPLE*$TARGET_BAM | xargs ls -t) ) #an array!  sorted by time

        #take the LAST modified BAM file that matches the target:
        LATEST_BAM_FILE=${ALL_BAM_FILES[0]}

	if [ "$LATEST_BAM_FILE" != "" ]; then
		echo "Most recent BAM file for $SAMPLE: $LATEST_BAM_FILE"
		SAMPLE_ALN_DIR=$PROJECT_DIR'/'$SAMPLE_DIR_PREFIX$SAMPLE'/'$ALN_DIR_NAME
		mkdir -p $SAMPLE_ALN_DIR
		ln -s $LATEST_BAM_FILE $SAMPLE_ALN_DIR'/'$FINAL_BAM_FILE
		ln -s $LATEST_BAM_FILE$BAM_IDX_EXTENSION $SAMPLE_ALN_DIR'/'$FINAL_BAM_FILE$BAM_IDX_EXTENSION
		printf "%s\t%s\n" $(echo $SAMPLE) $(echo $line | awk '{print $2}') >> $VALID_SAMPLE_FILE
	else
		echo "Could not locate a properly named BAM file for sample "$SAMPLE
	fi
    done < $SAMPLES_FILE

    echo "Found BAM files for the following samples:"
    print_sample_report $VALID_SAMPLE_FILE
    
fi

echo "
#########################################################################################################################################
#                                                                                                                                       #
#                                                     Alignment Section (end)                                                           #
#                                                                                                                                       #
#########################################################################################################################################
"


########## check for the appropriate bam files and update the valid sample file accordingly: #####################################################
$PYTHON $CHECK_BAM_SCRIPT || { ( set -o posix ; set ) >>$PROJECT_DIR/$VARIABLES; echo "Error when checking for BAM files, prior to read counting.  Exiting"; exit 1; }

echo "
#########################################################################################################################################
#                                                                                                                                       #
#                                                     Read Counting Section                                                             #
#                                                                                                                                       #
#########################################################################################################################################
"

# create or move the count files to prepare for differential analysis:

mkdir -p $COUNTS_DIR

if [ ! -d "$COUNTS_DIR" ]; then
    echo "Could not create the count directory (permissions?).  Exiting"
    exit 1
fi

if [ $TEST -eq $NUM0 ]; then

	#if used STAR for alignment or was directly provided with BAM files, get the read counts: 
	if [[ $ALIGNER == $STAR  ]] || [[ $ALN -eq $NUM0 ]] ; then

		#a tag for the temporary count file:
		TMP='.tmp'

    		#create the count files from the BAM files
    		for sample in $( cut -f1 $VALID_SAMPLE_FILE ); do
		    COUNT_FILE=$COUNTS_DIR'/'$sample$COUNTFILE_SUFFIX

    		    featureCounts -a $GTF \
				  -o $COUNT_FILE$TMP \
				  -t exon \
				  -g gene_name $PROJECT_DIR"/"$SAMPLE_DIR_PREFIX$sample"/"$ALN_DIR_NAME"/"$sample$FINAL_BAM_SUFFIX

		    Rscript \
			$PROCESS_COUNT_FILE_SCRIPT \
			$COUNT_FILE$TMP \
			$COUNT_FILE || { ( set -o posix ; set ) >>$PROJECT_DIR/$VARIABLES; echo "Parsing of the raw count files failed.  Exiting."; exit 1; }
		    
                    rm $COUNT_FILE$TMP &
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

# with the count files moved, create a design matrix for count normalization/DESeq:
$PYTHON $CREATE_DESIGN_MATRIX_SCRIPT || { ( set -o posix ; set ) >>$PROJECT_DIR/$VARIABLES; echo "Failed in creating design matrix.  Exiting"; exit 1; }

# create a normalized count matrix via DESeq:
NORMALIZED_COUNTS_FILE=$COUNTS_DIR'/'$NORMALIZED_COUNTS_FILE
export NORMALIZED_COUNTS_FILE

if [ $TEST -eq $NUM0 ]; then
	Rscript $NORMALIZED_COUNTS_SCRIPT $DESIGN_MTX_FILE $NORMALIZED_COUNTS_FILE
else
	echo "Perform mock normalized counts with DESeq."
fi


echo "
#########################################################################################################################################
#                                                                                                                                       #
#                                                     Read Counting Section (end)                                                       #
#                                                                                                                                       #
#########################################################################################################################################
"


echo "
###########################################################################################################
#                                                                                                         #  
#                                       RNA-SEQC SECTION                                                  #  
#                                                                                                         #  
###########################################################################################################
"

#create the reports with RNA-seQC:
while read line; do
 	SAMPLE=$(echo $line | awk '{print $1}')
	SAMPLE_BAM=$PROJECT_DIR'/'$SAMPLE_DIR_PREFIX$SAMPLE'/'$ALN_DIR_NAME'/'$SAMPLE$FINAL_BAM_SUFFIX

        #create output directory
        SAMPLE_QC_DIR=$REPORT_DIR'/'$RNA_SEQC_DIR'/'$SAMPLE
        mkdir -p $SAMPLE_QC_DIR
 
    	if [ $TEST -eq $NUM0 ]; then
		java -jar $RNA_SEQC_JAR \
		-o $SAMPLE_QC_DIR \
		-r $GENOMEFASTA \
		-s "$SAMPLE|$SAMPLE_BAM|-" \
		-t $GTF_FOR_RNASEQC || { ( set -o posix ; set ) >>$PROJECT_DIR/$VARIABLES; echo "Something failed on performing QC step.  Check the output for guidance."; }
	else
		echo "Perform mock QC analysis, etc. on "$SAMPLE
	fi
done < $VALID_SAMPLE_FILE

echo "
###########################################################################################################
#                                                                                                         #  
#                                       RNA-SEQC SECTION   (end)                                          #  
#                                                                                                         #  
###########################################################################################################
"


echo "
###########################################################################################################
#                                                                                                         #  
#                                            DESEQ SECTION                                                #  
#                                                                                                         #  
###########################################################################################################
"

if [ $SKIP_ANALYSIS -eq $NUM0 ]; then

	#first create an output directory for the deseq scripts that will be run:
	DESEQ_RESULT_DIR=$REPORT_DIR'/'$DESEQ_RESULT_DIR
	mkdir $DESEQ_RESULT_DIR


	if [ -e "$CONTRAST_FILE" ]; then
		echo "Run differential expression with DESeq"
		while read contrast; do
    			conditionA=$(echo $contrast | awk '{print $1}')
    			conditionB=$(echo $contrast | awk '{print $2}')

    			if [ $TEST -eq $NUM0 ]; then
    				echo Rscript $DESEQ_SCRIPT $DESEQ_RESULT_DIR $DESIGN_MTX_FILE $DESEQ_OUTFILE_TAG $conditionA $conditionB $HEATMAP_FILE $HEATMAP_GENE_COUNT $CONTRAST_FLAG
    				Rscript $DESEQ_SCRIPT $DESEQ_RESULT_DIR $DESIGN_MTX_FILE $DESEQ_OUTFILE_TAG $conditionA $conditionB $HEATMAP_FILE $HEATMAP_GENE_COUNT $CONTRAST_FLAG || { ( set -o posix ; set ) >>$PROJECT_DIR/$VARIABLES; echo "Error during DESeq script.  Exiting"; exit 1; }
			else
				echo "Perform mock DESeq step on contrast between "$conditionA "and" $conditionB
    			fi
		done < $CONTRAST_FILE
	else
		echo -e "\nSkipping differential analysis since no contrast file was specified.\n"
	fi
else
	echo -e "\nSkipping differential analysis since -align_only flag was set.\n"
fi

echo "
###########################################################################################################
#                                                                                                         #  
#                                            DESEQ SECTION  (end)                                         #  
#                                                                                                         #  
###########################################################################################################
"


echo "
###########################################################################################################
#                                                                                                         #  
#                                              GSEA SECTION                                               #  
#                                                                                                         #  
###########################################################################################################
"

if [ $SKIP_ANALYSIS -eq $NUM0 ]; then

	#create the GSEA directory:
	GSEA_OUTPUT_DIR=$REPORT_DIR'/'$GSEA_OUTPUT_DIR
	mkdir $GSEA_OUTPUT_DIR
	export GSEA_OUTPUT_DIR
	
	#create the formatted GSEA input files
	GSEA_CLS_FILE=$GSEA_OUTPUT_DIR'/'$GSEA_CLS_FILE
	GSEA_GCT_FILE=$GSEA_OUTPUT_DIR'/'$GSEA_GCT_FILE

	Rscript $CREATE_GSEA_CLS_SCRIPT $VALID_SAMPLE_FILE $GSEA_CLS_FILE
	Rscript $CREATE_GSEA_GCT_SCRIPT $NORMALIZED_COUNTS_FILE $VALID_SAMPLE_FILE $GSEA_GCT_FILE


	if [ -e "$CONTRAST_FILE" ]; then
	        while read contrast; do
        	        conditionA=$(echo $contrast | awk '{print $1}')
                	conditionB=$(echo $contrast | awk '{print $2}')

      	        	if [ $TEST -eq $NUM0 ]; then
				$RUN_GSEA_SCRIPT \
				$GSEA_JAR \
				$GSEA_ANALYSIS \
				$GSEA_GCT_FILE \
				$GSEA_CLS_FILE \
				$conditionA'_versus_'$conditionB \
				$DEFAULT_GMX_FILE \
				$NUM_GSEA_PERMUTATIONS \
				$conditionA$CONTRAST_FLAG$conditionB \
				$DEFAULT_CHIP_FILE \
				$GSEA_OUTPUT_DIR || { ( set -o posix ; set ) >>$PROJECT_DIR/$VARIABLES; echo "Error occurred in running GSEA.  Exiting."; exit 1; }
         	        else
                    		echo "Perform mock GSEA step on contrast between "$conditionA "and" $conditionB
			fi
        	done < $CONTRAST_FILE
	else
	    	echo -e "\nSkipping GSEA analysis since no contrast file was specified.\n"
	fi
else
	echo -e "\nSkipping GSEA analysis since -align_only flag was set.\n"
fi

echo "
###########################################################################################################
#                                                                                                         #  
#                                              GSEA SECTION (end)                                         #  
#                                                                                                         #  
###########################################################################################################
"

echo "
###########################################################################################################
#                                                                                                         #  
#                                               REPORT SECTION                                            #  
#                                                                                                         #  
###########################################################################################################
"

#copy the necessary libraries to go with the html report:
cp -r $REPORT_TEMPLATE_LIBRARIES $REPORT_DIR

#run the injection script to create the report:
if [ $TEST -eq $NUM0 ]; then
	$PYTHON $CREATE_REPORT_SCRIPT || { ( set -o posix ; set ) >>$PROJECT_DIR/$VARIABLES; echo "Error creating the report.  Exiting. "; exit 1; }
else
	echo "Perform mock creation of output report."
fi

echo "
###########################################################################################################
#                                                                                                         #  
#                                               REPORT SECTION (end)                                      #  
#                                                                                                         #  
###########################################################################################################
"

echo "
###########################################################################################################
#                                                                                                         #  
#                                            Moving/cleanup SECTION                                       #  
#                                                                                                         #  
###########################################################################################################
"

#move everything to the target directory:

# create the same directory structure as the PROJECT_DIR
find $PROJECT_DIR -type d -not -path "$PROJECT_DIR" | sed -e "s:$PROJECT_DIR:$TARGET_DIR:g" | xargs -t -i mkdir {}

# move all the files (EXCEPT FASTQ) into the target directory:
find $PROJECT_DIR -type f | grep -Pv ".*$FASTQ_SUFFIX" | sed -e "s:.*:'&':;p;s:$PROJECT_DIR:$TARGET_DIR:g" | xargs -t -n2 mv

#close the logging block
} | tee $TARGET_DIR/$LOGFILE

echo "
###########################################################################################################
#                                                                                                         #  
#                                            Moving/cleanup SECTION (end)                                 #  
#                                                                                                         #  
###########################################################################################################
"



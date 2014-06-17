"""
This script is run on aligned data-- 
  Given info about the project, look into the sample-specific directories and locate the bam files
  If the bam files do not exist, update the file containing the 'valid' samples, removing this sample
  In this way, we will not attempt to run a differential analysis on samples where we do not have the necessary data
  Additionally, we will not prepare a QC report for samples that do not have BAM files
"""

import sys
import os


def main(valid_sample_file, project_dir, sample_dir_prefix, align_dir_name, bam_suffix):

  #read the file that has the valid samples-- check that the bam files actually exist:
  valid_samples = []
  try:
    with open(valid_sample_file, 'r') as vsf:
      for line in vsf:
        sample_condition_tuple = tuple(line.strip().split('\t'))
        sample = sample_condition_tuple[0]
        sample_dir = os.path.join(project_dir, str(sample_dir_prefix)+str(sample))
        align_dir = os.path.join(sample_dir, align_dir_name)

        #check that this sample has a bam file:
        if os.path.exists(os.path.join(align_dir, str(sample)+str(bam_suffix))):
          valid_samples.append(sample_condition_tuple)
        else:
          print "BAM or count file was not found for sample "+str(sample)+".  Perhaps the alignment failed?"

    #rewrite the valid sample file to reflect the valid data:
    with open(valid_sample_file, 'w') as vsf:
      for sample, condition in valid_samples:
        vsf.write(str(sample)+"\t"+str(condition)+"\n")
  except IOError:
    sys.exit("I/O exception when reading the valid samples file: "+str(valid_sample_file))
       
if __name__=="__main__":

  try:
    valid_sample_file = os.environ['VALID_SAMPLE_FILE']
    project_dir = os.environ['PROJECT_DIR']
    sample_dir_prefix = os.environ['SAMPLE_DIR_PREFIX']
    align_dir_name = os.environ['ALN_DIR_NAME']
    bam_suffix = str(os.environ['SORTED_TAG'])+str(os.environ['BAM_EXTENSION'])
    
    main(valid_sample_file, project_dir, sample_dir_prefix, align_dir_name, bam_suffix)

  except KeyError:
    sys.exit("There was an error in the script while checking for BAM files.")


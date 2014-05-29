"""
This script prepares a design matrix for use with the differential analysis 
   -- it finds count files (via sample name and the countfile extension) and writes them to a file
   -- if it cannot find the count file, it skips writing.
"""

import sys
import os
import glob


def main(valid_sample_file, design_mtx_file, project_dir, countfile_dir, countfile_suffix):

  #read the file that has the valid samples-- check that the count files actually exist:
  countfile_dir = os.path.join(project_dir, countfile_dir)
  valid_samples = []
  with open(design_mtx_file, 'w') as design_file:
    design_file.write("sample\tfile\tcondition\n")

    try:
      with open(valid_sample_file, 'r') as vsf:
        for line in vsf:
          sample_condition_tuple = tuple(line.strip().split('\t'))
          sample = sample_condition_tuple[0]
          condition = sample_condition_tuple[1]

          #check that this sample has a count file:
          cf = glob.glob(os.path.join(countfile_dir, str(sample))+"*"+str(countfile_suffix))[0]
          if os.path.isfile(cf):
            design_file.write(str(sample)+"\t"+str(cf)+"\t"+str(condition)+"\n")
    except IOError:
      sys.exit("Could not open the sample file: "+str(valid_sample_file))        
       
if __name__=="__main__":

  #see the meaning of the input args further below
  if len(sys.argv) == 6:
    valid_sample_file = sys.argv[1]
    design_mtx_file = sys.argv[2]
    project_dir = sys.argv[3]
    countfile_dir = sys.argv[4]
    countfile_suffix = sys.argv[5]
    
    main(valid_sample_file, design_mtx_file, project_dir, countfile_dir, countfile_suffix)

  else:
    print "Please provide the correct input args:\n"
    print "\t1: The 'valid samples' file (produced by another python script\n"
    print "\t2: An output file for the design matrix file (to be ingested by R when running differential analysis)\n"
    print "\t3: The project directory \n"
    print "\t4: The directory containing all the count files (just the name, not a full path)\n"
    print "\t5: The suffix for the count files\n"

    sys.exit("Failed at creating design matrix for differential expression analysis.")

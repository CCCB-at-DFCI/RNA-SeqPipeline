import re
import sys
import os
import glob
import shutil

"""
Takes the following arguments:
1: a full path to the html template file.  This *should* be centrally located-- since it is just read-in
2: full path to the completed html file (the one to be filled-in).  This should ideally be in the output report directory
3: the valid sample file used in other steps of the pipeline. Two columns-- first column is the sample names
4: full path to a directory containing ALL the RNA-seQC reports.  This is located inside the output report directory
5: the name of the default output html created by RNA-seQC (usually report.html)
6: full path to the directory containing the deseq results (normalized count files, differential contrast results)
7: the name (NOT full path) of the heatmap created by Deseq.  Assumed to be located inside the deseq_results directory
8: the name (NOT full path) of the file containing the normalized counts. This file is assumed to be located inside the deseq results directory
"""

#some regexes:
QC_SEARCH_STRING = "#QC_REPORT#"
DESEQ_SEARCH_STRING = "#DIFFERENTIAL_EXP_RESULTS#"
CONTRAST_ID = "#CONTRAST_ID#"
DESEQ_FILE_LINK = "#DESEQ_FILE_LINK#"
TRUNCATED_DESEQ_FILENAME = "#TRUNCATED_DESEQ_FILENAME#"
SAMPLE_ID = "#SAMPLE_ID#"
REPORT_LINK = "#REPORT_LINK#"
HEATMAP_SEARCH_STRING = "#HEATMAP#"
HEATMAP_LOCATION = "#HEATMAP_LOCATION#"
NORM_COUNT_SEARCH_STRING = "#NORM_COUNT_FILE#"
NORM_COUNT = "#NORM_COUNT_FILE_LINK#"
TRUNCATED_NORM_COUNT_FILENAME = "#TRUNCATED_NORM_COUNT_FILENAME#"
DIV_REGEX = "<div.*</div>" #greedy match!


def get_search_pattern(target):
    return "<!--\s*"+str(target)+".*"+str(target)+"\s*-->"


def extract_template_textblock(pattern, template_html):
    matches = re.findall(pattern, template_html, flags=re.DOTALL)
    try:
        return matches[0] #the block of html that is the template
    except IndexError:
        print "Could not find a proper match in the template file."


def read_template_html(template_html_file):
    #read-in the template:
    try:
      with open(template_html_file, 'r') as report_template:
        return report_template.read()
    except IOError:
      sys.exit('Could not locate the template html file.')  

def get_sample_ids(samples_file):
    #parse the sample file:
    all_sample_ids = []
    try:
        with open(samples_file) as sf:
            for line in sf:
                all_sample_ids.append(line.strip().split('\t')[0])
        return all_sample_ids
    except IOError:
        sys.exit('Could not locate the sample file: '+str(samples_file))


def get_deseq_files(deseq_result_dir, deseq_output_tag):
    path = os.path.join(deseq_result_dir, "*"+deseq_output_tag+"*")
    return glob.glob(path)

def inject_qc_reports(output_report_dir, template_html, all_sample_ids, qc_dir, sample_report, error_report):

    pattern = get_search_pattern(QC_SEARCH_STRING)
    match = extract_template_textblock(pattern, template_html)
    if match:
        new_content = ""
        for sample_id in all_sample_ids:
            s = match
            s = re.sub(SAMPLE_ID, sample_id, s)

            #a location relative to the output directory (for use in the html page)
            qc_report = os.path.join(qc_dir, sample_id, sample_report)
            
            #an absolute location of the html report on the filesystem
            absolute_location = os.path.join(output_report_dir, qc_report)

            #if the qc report was not created (e.g. error with RNA-SeQC)
            if not os.path.isfile(absolute_location):
                print 'Could not find result report for sample '+str(sample_id)
                if not os.path.isdir(os.path.dirname(absolute_location)):
                    print 'Creating directory at'+str(os.path.dirname(absolute_location))
                    os.makedirs(os.path.dirname(absolute_location))		
                open(absolute_location, 'a').close() #'touch' the file
                print 'Copying error report'
                shutil.copy(error_report, absolute_location)
            s = re.sub(REPORT_LINK, qc_report, s)

            content = re.findall(DIV_REGEX, s, flags=re.DOTALL)
            new_content += content[0]

        template_html = re.sub(pattern, new_content, template_html, flags=re.DOTALL)
    return template_html


def inject_heatmap(template_html, heatmap_filepath):

    pattern = get_search_pattern(HEATMAP_SEARCH_STRING)
    match = extract_template_textblock(pattern, template_html)
    if match:
        match = re.sub(HEATMAP_LOCATION, heatmap_filepath, match)
        content = re.findall(DIV_REGEX, match, flags=re.DOTALL)
        template_html = re.sub(pattern, content[0], template_html, flags=re.DOTALL)
    return template_html


def inject_deseq_results(template_html, deseq_dir, deseq_files):

    pattern = get_search_pattern(DESEQ_SEARCH_STRING)
    match = extract_template_textblock(pattern, template_html)
    if match:
        new_content = ""
        if len(deseq_files)>0:
            for f in deseq_files:
                f = os.path.basename(f)
                s = match
                s = re.sub(CONTRAST_ID, f.split('.')[0], s)
                s = re.sub(DESEQ_FILE_LINK, os.path.join(deseq_dir, f), s)
                s = re.sub(TRUNCATED_DESEQ_FILENAME, f, s)
                content = re.findall(DIV_REGEX, s, flags=re.DOTALL)
                new_content += content[0]
        else:
            new_content='<div class="alert alert-info">Differential analysis was not performed</div>'

        template_html = re.sub(pattern, new_content, template_html, flags=re.DOTALL)
    return template_html


def inject_normalized_count_file(template_html, normalized_count_filepath):

    pattern = get_search_pattern(NORM_COUNT_SEARCH_STRING)
    match = extract_template_textblock(pattern, template_html)
    if match:
        match = re.sub(NORM_COUNT, normalized_count_filepath, match)
        match = re.sub(TRUNCATED_NORM_COUNT_FILENAME, os.path.basename(normalized_count_filepath), match)
        content = re.findall(DIV_REGEX, match, flags=re.DOTALL)
        template_html = re.sub(pattern, content[0], template_html, flags=re.DOTALL)
    return template_html


def write_completed_template(completed_html_report, template_html):
    with open(completed_html_report, 'w') as outfile:
        outfile.write(template_html)


if __name__ == "__main__":

    if len(sys.argv) == 11:
        template_html_file = sys.argv[1]
        completed_html_report = sys.argv[2]
        sample_file = sys.argv[3] #the full path to the valid sample file
        qc_dir = sys.argv[4]
        sample_report = sys.argv[5]
        deseq_result_dir = sys.argv[6]
        heatmap_file = sys.argv[7]
        normalized_count_file = sys.argv[8]
        deseq_output_tag = sys.argv[9]
        error_report_file = sys.argv[10]

        #ensure error file exists and read into a string:
        if not os.path.isfile(error_report_file):
            sys.exit("Could not locate the error report at: "+str(error_report_file))

        #the directory of the results:
        output_report_dir = os.path.dirname(completed_html_report)

        #get the deseq files:
        all_deseq_files = get_deseq_files(deseq_result_dir, deseq_output_tag)

        #get the basename for the directory of the deseq results-- files are relative to this
        deseq_result_dir = os.path.basename(deseq_result_dir)

        #get the basename of the directory of the html report--
        # all files should be RELATIVE to this so if the folder is moved, the links are not broken
        qc_dir = os.path.basename(qc_dir)

        #read the template into a string:
        html = read_template_html(template_html_file)

        #get the samples
        all_samples = get_sample_ids(sample_file)

        html = inject_qc_reports(output_report_dir, html, all_samples, qc_dir, sample_report, error_report_file)
        html = inject_heatmap(html, os.path.join(deseq_result_dir, heatmap_file))
        html = inject_normalized_count_file(html, os.path.join(deseq_result_dir, normalized_count_file))
        html = inject_deseq_results(html, deseq_result_dir, all_deseq_files)

        write_completed_template(completed_html_report, html)

    else:
        print "Error in creating HTML report.  Check the input args"
        sys.exit(1)

import re
import sys
import os
import glob
import shutil

#some regexes:
QC_SEARCH_STRING = "#QC_REPORT#"
GSEA_SEARCH_STRING = "#GSEA_REPORT#"
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
DEFAULT_HELP_SECTIONS = [
    "#DESEQ_ANALYSIS_HELP#",
    "#QUALITY_REPORT_HELP#",
    "#NORMALIZED_COUNTS_HELP#",
    "#HEATMAP_HELP#"]
NO_ALIGNER_HELP = "#NO_ALIGNER_HELP#"
STAR_ALIGNER_HELP = "#STAR_ALIGNER_HELP#"
SNAPR_ALIGNER_HELP = "#SNAPR_ALIGNER_HELP#"
OUTPUT_EXPLANATION = "#OUTPUT_EXPLANATION#"

STAR = os.environ['STAR']
SNAPR = os.environ['SNAPR']

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


def get_deseq_files(deseq_result_dir, file_tag):
    path = os.path.join(deseq_result_dir, "*"+file_tag+"*")
    return glob.glob(path)


def inject_help_section(template_html, help_html_file, aligner):
    
    new_content = ""
    help_text = read_template_html(help_html_file)
    for section in DEFAULT_HELP_SECTIONS:
        content = re.findall(DIV_REGEX, extract_template_textblock(str(section)+".*"+str(section), help_text), flags=re.DOTALL)
        new_content += content[0]

    #aligner-specific help
    if aligner.lower() == STAR.lower():
        section = STAR_ALIGNER_HELP
    elif aligner.lower() == SNAPR.lower():
        section = STAR_ALIGNER_HELP
    else:
        section = NO_ALIGNER_HELP

    content = re.findall(DIV_REGEX, extract_template_textblock(str(section)+".*"+str(section), help_text), flags=re.DOTALL)
    new_content += content[0]

    #place the new content into the output page:
    pattern = get_search_pattern(OUTPUT_EXPLANATION)
    template_html = re.sub(pattern, new_content, template_html, flags=re.DOTALL)
    return template_html


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


def inject_gsea_reports(output_report_dir, template_html, gsea_dir, gsea_default_html):

    pattern = get_search_pattern(GSEA_SEARCH_STRING)
    match = extract_template_textblock(pattern, template_html)
    if match:
	new_content = ""

        #get all the reports contained in the gsea directory:
        all_reports = glob.glob(os.path.join(gsea_dir, '*', gsea_default_html))

        for report in all_reports:
            #to the report relative to the output report directory
            relative_path = os.path.relpath(report, output_report_dir)
        
            #get the name of the contrast by parsing the report's parent directory
            parent_dir_name = os.path.basename(os.path.dirname(report))
            contrast_id = parent_dir_name.split('.')[0]

            s = match
            s = re.sub(CONTRAST_ID, contrast_id, s)
            s = re.sub(REPORT_LINK, relative_path, s)

            content = re.findall(DIV_REGEX, s, flags=re.DOTALL)
            new_content += content[0]

        template_html = re.sub(pattern, new_content, template_html, flags=re.DOTALL)
    return template_html


def inject_heatmaps(template_html, deseq_result_dir, all_heatmap_files, heatmap_file_tag):

    pattern = get_search_pattern(HEATMAP_SEARCH_STRING)
    match = extract_template_textblock(pattern, template_html)
    if match:
        new_content = ""
        for heatmap in all_heatmap_files:
            f = os.path.basename(heatmap).rstrip(heatmap_file_tag) #get the 'name' of the contrast performed
            s = match
            s = re.sub(CONTRAST_ID, f, s)
            s = re.sub(HEATMAP_LOCATION, os.path.join(deseq_result_dir, os.path.basename(heatmap)), s)
            content = re.findall(DIV_REGEX, s, flags=re.DOTALL)
            new_content += content[0]
        template_html = re.sub(pattern, new_content, template_html, flags=re.DOTALL)
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


def inject_normalized_count_file(template_html, normalized_count_filepath, output_report_dir):

    pattern = get_search_pattern(NORM_COUNT_SEARCH_STRING)
    match = extract_template_textblock(pattern, template_html)
    if match:
        match = re.sub(NORM_COUNT, os.path.relpath(normalized_count_filepath, output_report_dir), match)
        match = re.sub(TRUNCATED_NORM_COUNT_FILENAME, os.path.basename(normalized_count_filepath), match)
        content = re.findall(DIV_REGEX, match, flags=re.DOTALL)
        template_html = re.sub(pattern, content[0], template_html, flags=re.DOTALL)
    return template_html


def write_completed_template(completed_html_report, template_html):
    with open(completed_html_report, 'w') as outfile:
        outfile.write(template_html)


if __name__ == "__main__":

    try:
        template_html_file = os.environ['REPORT_TEMPLATE_HTML'] #full path to the template html file
        completed_html_report = os.path.join(os.environ['REPORT_DIR'], os.environ['FINAL_RESULTS_REPORT']) #full path to the formatted html file that will be created
        sample_file = os.environ['VALID_SAMPLE_FILE'] #the full path to the valid sample file
        qc_dir = os.path.join(os.environ['REPORT_DIR'], os.environ['RNA_SEQC_DIR']) #full path to the QC output files
        sample_report = os.environ['DEFAULT_RNA_SEQC_REPORT'] #the name of the default output html report created by RNA-SeQC
        deseq_result_dir = os.environ['DESEQ_RESULT_DIR'] #full path to the directory containing the DESeq results
        heatmap_file_tag = os.environ['HEATMAP_FILE'] # a string/tag used to identify heatmap files (which are located in deseq_result_dir)
        normalized_count_file = os.environ['NORMALIZED_COUNTS_FILE'] #the full path of the file for the normalized counts
        deseq_output_tag = os.environ['DESEQ_OUTFILE_TAG'] # a string/tag used for identifying the output contrast files from DESeq
        error_report_file = os.environ['ERROR_PAGE'] #full path to a html page which serves as an error page (in case RNASeQC fails)
        help_html_file = os.environ['HELP_PAGE_CONTENT'] #full path to a template page containing the help information
        aligner = os.environ['ALIGNER'] #which aligner was used
        gsea_dir = os.environ['GSEA_OUTPUT_DIR'] #full path to the directory containing the GSEA analyses
        gsea_default_html = os.environ['GSEA_DEFAULT_HTML'] #the name of the default html report that GSEA produces

        #ensure error file exists and read into a string:
        if not os.path.isfile(error_report_file):
            sys.exit("Could not locate the error report at: "+str(error_report_file))

        #the directory of the results:
        output_report_dir = os.path.dirname(completed_html_report)

        #get the deseq files:
        all_deseq_files = get_deseq_files(deseq_result_dir, deseq_output_tag)

	#get the heatmap files:
        all_heatmap_files = get_deseq_files(deseq_result_dir, heatmap_file_tag)

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
        html = inject_heatmaps(html, deseq_result_dir, all_heatmap_files, heatmap_file_tag)
        html = inject_normalized_count_file(html, normalized_count_file, output_report_dir)
        html = inject_deseq_results(html, deseq_result_dir, all_deseq_files)
        html = inject_help_section(html, help_html_file, aligner)
        html = inject_gsea_reports(output_report_dir, html, gsea_dir, gsea_default_html)

        write_completed_template(completed_html_report, html)

    except KeyError:
        print "Error in creating HTML report.  Check the input args"
        sys.exit(1)

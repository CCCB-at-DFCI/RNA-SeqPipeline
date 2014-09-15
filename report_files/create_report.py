import os
import glob
import sys
import re
import fnmatch
import traceback

# required html template elements:
accordion_panel="accordion_panel"
file_link="file_link"
iframe="iframe"
img_content="img_content"
new_tab="new_tab"
tab_content="tab_content"
required_elements = [accordion_panel, file_link, iframe, img_content, new_tab, tab_content]

HTML="html"
IMG_TYPES=["png", "jpg", "jpeg"]

# some constants.  These are flags that are in the template html files.  They are used as placeholders for values we will fill-in
TAB_SECTION="#TAB_SECTION#"
CONTENT_SECTION="#CONTENT_SECTION#"
ID="#ID#"
LINK="#LINK#"
SECTION_HEADER="#SECTION_HEADER#"
REPEATING_COMPONENT="#REPEATING_COMPONENT#"
FILE_NAME="#FILE_NAME#"
RETURN_LINK_TEXT="#RETURN_LINK_TEXT#"
TAB_TEXT="#TAB_TEXT#"
PANEL_ID="#PANEL_ID#"
PANEL_TITLE="#PANEL_TITLE#"
PANEL_CONTENT="#PANEL_CONTENT#"
DGE_ANALYSIS="#DGE_ANALYSIS#"
ALIGNER="#ALIGNER#"
ALIGNER_REF_URL="#ALIGNER_REF_URL#"
ASSEMBLY="#ASSEMBLY#"

def read_file(filepath):
	#read-in a file to a string:
	try:
		with open(filepath, 'r') as text:
			return text.read()
	except IOError:
		sys.exit('Could not locate the following file:' +str(filepath))  


def get_sample_ids(samples_file):
	#parse the sample file and return a list of the sample names (strings):
	all_sample_ids = []
	try:
		with open(samples_file) as sf:
			for line in sf:
				all_sample_ids.append(line.strip().split('\t')[0])
		return all_sample_ids
	except IOError:
		sys.exit('Could not locate the sample file: '+str(samples_file))


def get_contrasts(contrast_file):			
	#parse the contrast file and return a list of tuples (strings):
	all_contrasts = []
	try:
		with open(contrast_file) as cf:
			for line in cf:
				all_contrasts.append(tuple(line.strip().split('\t')))
		return all_contrasts
	except IOError:
		sys.exit('Could not locate the contrast file: '+str(contrast_file))


def read_template_elements(template_elements_dir, template_element_tag):
	"""
	This method finds all the html template element files and reads them into a dictionary.  
	The key is the beginning of the filename (without the identifying tag).
	The key points at a string, which is the template text
	"""
	template_dict = {}
	element_files = glob.glob(os.path.join(template_elements_dir, "*"+str(template_element_tag)))	
	if len(element_files)>0:
		for f in element_files:
			basename = os.path.basename(f)
			template_dict[basename[:-len(template_element_tag)]]=open(f, 'r').read()
	else:
		sys.exit("There was a problem locating the template element files located at: "+str(template_elements_dir))

	#check that the required templates were read:
	if any([x for x in required_elements if x not in template_dict.keys()]):
		sys.exit("Missing one of the required HTML templates.  Check that files with the extension "+str(template_element_tag)+" exist for all of: "+str(required_elements))
	return template_dict


def find_files(search_string, report_dir, samples=None, contrasts=None, tag=None):
	"""
	Given a search path and optionally a list of all the sample names
	Return a list of lists, where each list has the paths for files corresponding to a particular sample.  The sample reference is contained in the filename, so no need to carry that around
	"""
	found_files = glob.glob(search_string)
	valid_files = {}
	if samples:
		for sample in samples:
			valid_files[sample]=[x for x in found_files if sample in x]
	elif contrasts and tag:
		for a,b in contrasts:
			match1="*"+str(a)+"*"+str(tag)+"*"+str(b)+"*" 
			match2="*"+str(b)+"*"+str(tag)+"*"+str(a)+"*" 
			key = str(b)+str(tag)+str(a)
			#if the filenames 'match' (in a wildcard sense) the contrasted samples anywhere in the filepath, then point this contrast at that file (should only be 1)
			try:
				valid_files[key]=[found_files[[x for x,y in enumerate(found_files) if fnmatch.fnmatch(y, match1) or fnmatch.fnmatch(y, match2)][0]]]
			except IndexError: #if no match was found
				pass #just ignore
	#make links relative to the report directory:
	for key, files in valid_files.iteritems():
		valid_files[key] = [os.path.relpath(f, report_dir) for f in files]
			
	return valid_files


def search_pattern(target):
	return "<!--\s*"+str(target)+"\s*-->"


def insert(main_text, pattern, new_text):
	"""
	Inserts new_text into main_text and returns the modified main_text.  
	The argument 'pattern' defines the boundaries of the text region into which new_text is inserted.
	new_text is inserted as the last item in that region.
	"""
	search_pattern = str(pattern) + ".*" + str(pattern) # greedy regex to grab the region of interest
	m = re.search(search_pattern, main_text, flags=re.DOTALL) #get the section of text that matches our regex.
	block_start = m.start()
	block_end = m.end()
	
	#this loops through the occurrences of 'pattern' in the extracted text block.  Upon exiting the loop,
	# the variable pattern_match holds information about the last occurrence-- the end of our region.
	for pattern_match in re.finditer(pattern, main_text[block_start:block_end], flags=re.DOTALL):
		pass
	
	index=block_start+pattern_match.start() #the location (in the original main_text) of that last occurrence of 'pattern'
	return main_text[:index]+str(new_text)+main_text[index:] #insert the new text at that position and return.

	
def add_navigation_tab(main_html, template_dict, tab_text, id):

	#prepare the tab section
	tab_pattern = search_pattern(TAB_SECTION)
	tab_template_text = template_dict[new_tab]
	tab_template_text = re.sub(ID, "#"+str(id), tab_template_text)
	tab_template_text = re.sub(TAB_TEXT, tab_text, tab_template_text)

	return insert(main_html, tab_pattern, tab_template_text)


def create_content_item(filepath, template_dict, id):

	if filepath.lower().endswith(HTML.lower()):
		template = template_dict[iframe]
		template = re.sub(LINK, filepath, template)
		template = re.sub(ID, id, template)
		template = re.sub(RETURN_LINK_TEXT, "Back to original report", template)
	elif filepath.split('.')[-1].lower() in map(lambda s: s.lower(), IMG_TYPES):
		template = template_dict[img_content]
		template = re.sub(LINK, filepath, template)
	else:
		template = ""
	return template


def add_accordion_content(main_html, template_dict, tab_text, section_header, file_dict):
        """
	Adds a tab and page content for content that is held in accordion-style panels
        """

	id = tab_text.replace(" ","_") #create an ID used as a html id attribute (to reference the content panel).
        main_html = add_navigation_tab(main_html, template_dict, tab_text, id)

        #prepare the content section
        content_pattern = search_pattern(CONTENT_SECTION)
        content_template_text = template_dict[tab_content]
        content_template_text = re.sub(ID, id, content_template_text)
        content_template_text = re.sub(SECTION_HEADER, section_header, content_template_text)

        #for each of the files, insert a new accordion element into the content template
        acc_panel_template_text = template_dict[accordion_panel]
	
	for key, files in file_dict.iteritems():
	        for idx, path in enumerate(files):
			#create another ID:
			panel_id = str(id)+"_"+str(key)+"_"+str(idx)
        	        #replace in the template:
        	        new_panel = re.sub(PANEL_ID, panel_id, acc_panel_template_text)
			if len(files)==1:
	        	        new_panel = re.sub(PANEL_TITLE, key, new_panel)
			else:
	        	        new_panel = re.sub(PANEL_TITLE, str(key)+" ("+str(idx+1)+")", new_panel)
			

			#depending on type of file, sub in the content
			content_item = create_content_item(path, template_dict, panel_id)
			new_panel = insert(new_panel, search_pattern(PANEL_CONTENT), content_item)
        	        content_template_text = insert(content_template_text, search_pattern(REPEATING_COMPONENT), new_panel)

        main_html=insert(main_html, content_pattern, content_template_text)
        return main_html



def add_simple_link_content(main_html, template_dict, tab_text, section_header, file_dict, alias_link=False):
	"""
	Adds a tab and page content for simple links to the data files
	The arg 'file_dict' is a dictionary 
	"""
	id = tab_text.replace(" ","_") #create an ID used as a html id attribute (to reference the content panel).
	main_html = add_navigation_tab(main_html, template_dict, tab_text, id)

	#prepare the content section
	content_pattern = search_pattern(CONTENT_SECTION)	
	content_template_text = template_dict[tab_content]	
	content_template_text = re.sub(ID, id, content_template_text)
	content_template_text = re.sub(SECTION_HEADER, section_header, content_template_text)

	#for each of the files, insert a new file link into the content template
	file_link_template_text = template_dict[file_link]

	for key, files in file_dict.iteritems():
		for path in files:
			#replace in the template:
			new_file_link = re.sub(LINK, path, file_link_template_text)
			if alias_link:
				new_file_link = re.sub(FILE_NAME, key, new_file_link)
			else:
				new_file_link = re.sub(FILE_NAME, os.path.basename(path), new_file_link)
			#insert the link into the content block:
			content_template_text = insert(content_template_text, search_pattern(REPEATING_COMPONENT), new_file_link)		

	main_html=insert(main_html, content_pattern, content_template_text)
	return main_html


def unhide_analysis_help(main_html):
	pattern = "<!-- \s*"+str(DGE_ANALYSIS)+".*"+str(DGE_ANALYSIS)+"\s*-->"
	match = re.findall(pattern, main_html, flags=re.DOTALL)
	try:
		m = match[0] #the block of html that is the template
		submatch = re.findall("<div>.*</div>", m, flags=re.DOTALL)
		section = submatch[0]
		main_html = re.sub(pattern, section, main_html, flags=re.DOTALL)
		return main_html
	except IndexError:
		sys.exit("Could not parse the html file to extract the help section specific to differential gene expression")


def write_completed_template(completed_html_report, template_html):
	with open(completed_html_report, 'w') as outfile:
		outfile.write(template_html)


if __name__ == "__main__":

	try:
		template_html_file = os.environ['FINAL_REPORT_TEMPLATE_HTML'] #full path to the template html file
		completed_html_report = os.path.join(os.environ['REPORT_DIR'], os.environ['FINAL_RESULTS_REPORT']) #full path to the formatted html file that will be created
		template_elements_dir = os.environ['REPORT_HTML_TEMPLATES_DIR'] #full path to a directory containing the template html files and elements
		template_element_tag = os.environ['TEMPLATE_ELEMENT_TAG'] #file extension/tag to locate the pre-defined template html files
		sample_file = os.environ['VALID_SAMPLE_FILE'] #the full path to the valid sample file
		sample_dir_prefix = os.environ['SAMPLE_DIR_PREFIX']
		fastq_suffix = os.environ['FASTQ_SUFFIX']
		final_bam_suffix = os.environ['FINAL_BAM_SUFFIX']
		countfile_suffix = os.environ['COUNTFILE_SUFFIX']
		project_dir = os.environ['PROJECT_DIR']
		normalized_count_file = os.environ['NORMALIZED_COUNTS_FILE'] #the full path of the file for the normalized counts
		skip_analysis = int(os.environ['SKIP_ANALYSIS']) #a boolean (0,1) indicating if analysis beyond alignment was performed
		rna_qc_report = os.environ['DEFAULT_RNA_SEQC_REPORT'] #the name of the default output html report created by RNA-SeQC
		qc_dir = os.path.join(os.environ['REPORT_DIR'], os.environ['RNA_SEQC_DIR']) #full path to the QC output files
		fastqc_default_html = os.environ['FASTQC_DEFAULT_HTML'] #the name of the default html report created by fastqc
		aligner = os.environ['ALIGNER']
		aligner_ref_url = os.environ['ALIGNER_REF_URL']
		genome = os.environ['ASSEMBLY']

		#the directory of the results, which we can extract from the intended final location of the html report:
		output_report_dir = os.path.dirname(completed_html_report)

		#read the template HTML file into a string:
		main_html = read_file(template_html_file)

		#read the template HTML elements into a dictionary:
		template_element_dict = read_template_elements(template_elements_dir, template_element_tag)

		#get the sample names
		all_samples = get_sample_ids(sample_file)

		"""
		default sections of the output report include:
			-fastq files
			-fastqc reports
			-bam files
			-counts/normalized counts
			-RNA QC
		"""
		
		#plug-in some basic information:
		main_html = re.sub(ALIGNER, aligner, main_html)
		main_html = re.sub(ALIGNER_REF_URL, aligner_ref_url, main_html)
		main_html = re.sub(ASSEMBLY, genome, main_html)

		#for each of the file types, get a list of tuples containing the sample name and path:
		fastq_files = find_files(os.path.join(project_dir, str(sample_dir_prefix)+"*","*"+str(fastq_suffix)), output_report_dir, samples=all_samples)
		bam_files = find_files(os.path.join(project_dir, str(sample_dir_prefix)+"*", "*", "*"+str(final_bam_suffix)), output_report_dir, samples=all_samples)
		count_files = find_files(os.path.join(project_dir, str(output_report_dir), "*", "*"+str(countfile_suffix)), output_report_dir, samples=all_samples)
		norm_count_file = {}
		norm_count_file[os.path.basename(normalized_count_file)]=[os.path.relpath(normalized_count_file, output_report_dir)]
		rna_qc_files = find_files(os.path.join(project_dir, output_report_dir, qc_dir, "*", rna_qc_report), output_report_dir, samples=all_samples)
		fastqc_files = find_files(os.path.join(project_dir, "*", "*", fastqc_default_html), output_report_dir, samples=all_samples)

		main_html = add_simple_link_content(main_html, template_element_dict, "FASTQ Files", "Sequence files (FASTQ) in compressed format:", fastq_files)
		main_html = add_simple_link_content(main_html, template_element_dict, "BAM Files", "Binary sequence alignment files (BAM)", bam_files, alias_link=True)
		main_html = add_simple_link_content(main_html, template_element_dict, "Raw read-count Files", "Raw (sample-level) sequence counts", count_files, alias_link=True)
		main_html = add_simple_link_content(main_html, template_element_dict, "Normalized read-count Files", "Normalized count file", norm_count_file, alias_link=True)		
		main_html = add_accordion_content(main_html, template_element_dict, "RNA-Seq QC", "RNA-Seq experiment quality reports", rna_qc_files)
		main_html = add_accordion_content(main_html, template_element_dict, "FASTQC report", "Sequencing quality reports", fastqc_files)

		"""
		Other sections of the output report include:
			-deseq files
			-heatmaps
			-gsea
		"""
		if not skip_analysis:

			contrast_file = os.environ['CONTRAST_FILE'] #path to the contrast file
			contrast_tag = os.environ['CONTRAST_FLAG'] # a tag (typically "_vs_" for easy identification of the contrast-level files/analyses)
			deseq_outfile_tag = os.environ['DESEQ_OUTFILE_TAG'] # a string/tag used for identifying the output contrast files from DESeq
			heatmap_file_tag = os.environ['HEATMAP_FILE'] # a string/tag used to identify heatmap files (which are located in deseq_result_dir)
			gsea_dir = os.environ['GSEA_OUTPUT_DIR'] #full path to the directory containing the GSEA analyses
			gsea_default_html = os.environ['GSEA_DEFAULT_HTML'] #the name of the default html report that GSEA produces

			#parse the contrast file:
			all_contrasts = get_contrasts(contrast_file)			

			deseq_files = find_files(os.path.join(project_dir, output_report_dir, "*", "*"+str(deseq_outfile_tag)+"*"), output_report_dir, contrasts=all_contrasts, tag=contrast_tag)
			heatmap_files = find_files(os.path.join(project_dir, output_report_dir, "*", "*"+str(heatmap_file_tag)+"*"), output_report_dir, contrasts=all_contrasts, tag=contrast_tag)
			gsea_files = find_files(os.path.join(project_dir, output_report_dir, gsea_dir, "*", gsea_default_html), output_report_dir, contrasts=all_contrasts, tag=contrast_tag)

			main_html = add_simple_link_content(main_html, template_element_dict, "Differential Expression Analysis", "Results from differential expression analysis", deseq_files, alias_link=True)
			main_html = add_accordion_content(main_html, template_element_dict, "Heatmaps", "Heatmaps of the most highly expressed genes in each contrast", heatmap_files)
			main_html = add_accordion_content(main_html, template_element_dict, "GSEA", "Gene-set enrichment analysis of each between-group contrast", gsea_files)

			main_html = unhide_analysis_help(main_html)
		write_completed_template(completed_html_report, main_html)

	except KeyError:
		print traceback.format_exc()		
		print "Error in creating HTML report.  Check the input args"
		sys.exit(1)


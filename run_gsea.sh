#!/bin/bash

#$1 argument is the gsea jar
#$2 argument is the gsea tool
#$3 argument is the gct file
#$4 argument is the class file
#$5 argument specifies the contrast (e.g. X_versus_Y, where X and Y are a subset of the NAMES defined in line 2 of the .cls file)
#$6 argument is the gmx file
#$7 argument is the number of permutations to run in the analysis 
#$8 argument is the label for the analysis
#$9 argument is the chip file (GENE_SYMBOL.chip, typically)
#$10 argument is a path to an output directory where the result will be placed

echo "********************************"
echo "Arguments for GSEA analysis:"

for i; do
	echo $i
done
echo "********************************"
echo ""

java -cp $1 -Xmx1024m $2 \
-res $3 \
-cls $4#$5 \
-gmx $6 \
-collapse true \
-mode Max_probe \
-norm meandiv \
-nperm $7 \
-permute gene_set \
-rnd_type no_balance \
-scoring_scheme weighted \
-rpt_label $8 \
-metric Signal2Noise \
-sort real \
-order descending \
-chip $9 \
-include_only_symbols true \
-make_sets true \
-median false \
-num 100 \
-plot_top_x 20 \
-rnd_seed timestamp \
-save_rnd_lists false \
-set_max 50000 \
-set_min 15 \
-zip_report false \
-out ${10} \
-gui false

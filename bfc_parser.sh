#!/bin/bash

# Usage: bash bfc_parser.sh /path/to/folder/of/bfc/output
#
# This script parses the results of bfc error correction tool and produces summary output following: https://github.com/lh3/bfc
# The summary output will be written to the input folder.
#
# How it works:
# BFC adds a string to the header line of all reads in the fasta output as " ec:Z:[0-5]_a:h_b_l:h_0) ", where;
#	- first 0 indicates a succcesfully corrected read, while the failures would have been coded on the same field as:
#	    2: Many N's; 3: No solid k-mers; 4: Too many uncorrectable N's; 5: Many Failed Attempts
#	- a is the number of k-mers not present in the solid k-mer hash table (ideally 0), 
#	- h is the max heap size in correction (smaller is better), 
#	- b is 1 if and only if no raw k-mers are solid
#	- l is the number of corrections and,
#	- h is the number of high-quality corrections.
# The number of corrections and high-quality corrections are used to output read correction statistics.
#
# References:
# https://github.com/lh3/bfc/issues/9
# https://github.com/lh3/bfc/blob/master/correct.c#L138

in_dir=$1
mkdir -p work_dir

for file in $in_dir/*.fq.gz; do
	newname=$(basename $file | sed 's/.gz//g')
	gunzip -c $file > work_dir/$newname
	# Extract sample code from filename
	samplecode=$(basename $file | cut -d "." -f1)
	# Get the correction info added by BFC to the header line
	awk -F '\t' 'NR % 4 == 1 {print $2}' work_dir/$newname > work_dir/$samplecode.corr
	# Extract the string for non-corrected reads
	awk -F ":" '{print $3}' work_dir/$samplecode.corr | grep -v "^0" | sort -n | uniq -c | awk '{t = $1; $1 = $2; $2 = t; print;}' | sort -n -r -k2 > work_dir/$samplecode.failures
	# Get the number of total reads and write to a variable	
	total_reads=$(cat work_dir/$samplecode.corr | wc -l) 
	# Get the number of uncorrected reads and write to a variable
	uncorr_reads=$(awk '{s+=$2}END{print s}' work_dir/$samplecode.failures)
	# Print output using the extracted info
	printf "############################################" > $in_dir/$samplecode.bfc.log
	printf "\n        BFC error correction summary" >> $in_dir/$samplecode.bfc.log
	printf "\n############################################\n" >> $in_dir/$samplecode.bfc.log
	printf "\nInput total reads: %d" $total_reads >> $in_dir/$samplecode.bfc.log
	printf "\nCorrected reads percent: %.2f" $(echo "100-($uncorr_reads*100/$total_reads)" | bc -l) >> $in_dir/$samplecode.bfc.log
	printf "\nUncorrected reads: %d\n" $uncorr_reads >> $in_dir/$samplecode.bfc.log
	printf "\n--------------------------------------------" >> $in_dir/$samplecode.bfc.log
	printf "\nUncorrected reads reasons" >> $in_dir/$samplecode.bfc.log
	printf "\n--------------------------------------------\n" >> $in_dir/$samplecode.bfc.log
	awk '{if ($1==1) $1="MISC???: "; else if ($1==2) $1="Many Ns: "; else if ($1==3) $1="No solid k-mers: "; else if ($1==4) $1="Uncorrectable Ns: "; else if ($1==5) $1="Many failed attempts: "}1'  work_dir/$samplecode.failures >> $in_dir/$samplecode.bfc.log
	printf "\n--------------------------------------------">> $in_dir/$samplecode.bfc.log
	printf "\nCorrected reads tables" >> $in_dir/$samplecode.bfc.log
	printf "\n--------------------------------------------">> $in_dir/$samplecode.bfc.log
	printf "\n#_reads|#_corrections_per_read" >> $in_dir/$samplecode.bfc.log
	printf "\n" >> $in_dir/$samplecode.bfc.log
	# Extract option -l (Number of corrections per read)
	awk -F ':' '{print $4}'  work_dir/$samplecode.corr | awk -F '_' '{print $3}' | sed '/^$/d' | sort -n | uniq -c | tail -n +2 >> $in_dir/$samplecode.bfc.log	
	printf "\n#_reads|#_high_quality_corrections_per_read" >> $in_dir/$samplecode.bfc.log
	printf "\n" >> $in_dir/$samplecode.bfc.log
	# Extract option -h (Number of high quality corrections per read)	
	awk -F ':' '{print $5}'  work_dir/$samplecode.corr | awk -F '_' '{print $1}' | sed '/^$/d' | sort -n | uniq -c | tail -n +2 >> $in_dir/$samplecode.bfc.log
done

rm -rf work_dir
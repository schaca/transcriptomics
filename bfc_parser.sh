#!/bin/bash

# Usage: bash bfc_parser.sh -i /path/to/bfc/corrected/fastq/directory
#
# This script parses the results of bfc error correction tool and produces a summary output. The results are saved to the same directory.
# 
# Explanation:
# BFC adds a string to the header line of all reads in the fasta output as " ec:Z:[0-5]_a:h_b_l:h_0) ", where;
#	- first 0 indicates a succcesfully corrected read, while the failures are coded as:
#	    2-Many N's; 3-No solid k-mers; 4-Too many uncorrectable N's; 5-Many failed attempts,
#	- a is the number of k-mers not present in the solid k-mer hash table (ideally 0), 
#	- h is the max heap size in correction (smaller is better), 
#	- b is 1 if and only if no raw k-mers are solid
#	- l is the number of corrections and,
#	- h is the number of high-quality corrections.
# The number and percentage of corrections, high-quality corrections and the reasons for failure are summarized in output.
#
# https:/github.com/lh3/bfc
# https:/github.com/lh3/bfc/issues/9
# https:/github.com/lh3/bfc/blob/master/correct.c#L138

set -o errexit
set -o nounset

# Option parser
DEBUG=0
while [ $# -gt 0 ]; do
    case "$1" in
        -i|--indir)
            in_dir="$2"
            shift 2
            ;;
        --debug)
            DEBUG=1
            shift 1
            ;;
        *)
            break
            ;;
    esac
done

mkdir bfc_parser_tmp
cd bfc_parser_tmp

for file in ../$in_dir/*.fq.gz; do
	# Decompress fastq file
	gunzip -c "$file" > "${file/.gz/}"
	# Extract identifier from filename
	identifier=$(basename $file | cut -d "." -f1)
	# Extract the correction info added by BFC to the header lines
	awk -F '\t' 'NR % 4 == 1 {print $2}' "${file/.gz/}" > $identifier.corr
	# Extract the uncorrected reads from correction info
	awk -F ":" '{print $3}' $identifier.corr | grep -v "^0" | sort -n | uniq -c | awk '{t = $1; $1 = $2; $2 = t; print;}' | sort -n -r -k2 > $identifier.failures
	# Get the number of total reads and save 
	total_reads=$(cat $identifier.corr | wc -l) 
	# Get the number of uncorrected reads and save
	uncorr_reads=$(awk '{s+=$2}END{print s}' $identifier.failures)
	#Print output line by line using the extracted info
	printf "$(date)" > $identifier.bfc.summary.txt 
	printf "\nBash version: ${BASH_VERSION}\n" >> $identifier.bfc.summary.txt
	printf "\n############################################" >> $identifier.bfc.summary.txt
	printf "\n        BFC error correction summary" >> $identifier.bfc.summary.txt
	printf "\n############################################\n" >> $identifier.bfc.summary.txt
	printf "\nInput total reads: %d" $total_reads >> $identifier.bfc.summary.txt
	printf "\nCorrected reads percent: %.2f" $(echo "100-($uncorr_reads*100/$total_reads)" | bc -l) >> $identifier.bfc.summary.txt
	printf "\nUncorrected reads: %d\n" $uncorr_reads >> $identifier.bfc.summary.txt
	printf "\n--------------------------------------------" >> $identifier.bfc.summary.txt
	printf "\nUncorrected reads reasons" >> $identifier.bfc.summary.txt
	printf "\n--------------------------------------------\n" >> $identifier.bfc.summary.txt
	awk '{if ($1==1) $1="MISC???: "; else if ($1==2) $1="Many Ns: "; else if ($1==3) $1="No solid k-mers: "; else if ($1==4) $1="Uncorrectable Ns: "; else if ($1==5) $1="Many failed attempts: "}1'  $identifier.failures >> $identifier.bfc.summary.txt
	printf "\n--------------------------------------------">> $identifier.bfc.summary.txt
	printf "\nCorrected reads tables" >> $identifier.bfc.summary.txt
	printf "\n--------------------------------------------">> $identifier.bfc.summary.txt
	printf "\n#_reads|#_corrections_per_read" >> $identifier.bfc.summary.txt
	printf "\n" >> $identifier.bfc.summary.txt
	# Extract option -l (Number of corrections per read)
	awk -F ':' '{print $4}' $identifier.corr | awk -F '_' '{print $3}' | sed '/^$/d' | sort -n | uniq -c | tail -n +2 >> $identifier.bfc.summary.txt	
	printf "\n#_reads|#_high_quality_corrections_per_read" >> $identifier.bfc.summary.txt
	printf "\n" >> $identifier.bfc.summary.txt
	# Extract option -h (Number of high quality corrections per read)	
	awk -F ':' '{print $5}'  $identifier.corr | awk -F '_' '{print $1}' | sed '/^$/d' | sort -n | uniq -c | tail -n +2 >> $identifier.bfc.summary.txt
	rm "${file/.gz/}"
done

cd ..
cp bfc_parser_tmp/*.bfc.summary.txt $in_dir
rm -rf bfc_parser_tmp

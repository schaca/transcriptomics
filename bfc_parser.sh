#!/bin/bash

set -o errexit
set -o nounset

# Set environment variables
INDIR=
arg0="$(basename "$0" .sh)"

# Options and parser
usemsg="Usage: $arg0.sh [-h|--help][-V|--version][{-i|--indir} indir]"
usage() { echo "$usemsg" >&2; exit 1; }
error() { echo "$0 $*" >&2; usage; }

[[ $# -eq 0 ]] && error 
while [ $# -gt 0 ]
do
    case "$1" in
    -i|--indir)
        INDIR="$2"
        shift
        ;;
    -h|--help)
        echo "$usemsg"
	echo " "
	echo " Arguments:"
	echo "  [-i|--indir]	Path to bfc corrected fastq files"
        echo " "
	echo "	This script parses the results of bfc error correction tool and produces a summary output. The number and percentage of corrections, high-quality corrections and the reasons for failure are summarized. It processes all compressed fastq files in the input path, soit should only contain BFC corrected fastq files."
	echo " "
	echo "	Short explanation:"
	echo " "
	echo "	BFC adds a string to the sequence identifier line of all reads in the fasta output as 'ec:Z:[0-5]_a:h_b_l:h_0)', where;"
	echo "		-first 0 indicates a succcesfully corrected read, while the failures are coded as:"
	echo "			2-Many N's; 3-No solid k-mers; 4-Too many uncorrectable N's; 5-Many failed attempts,"
	echo " 		- l is the number of corrections, and"
	echo "		- h is the number of high-quality corrections."
	echo " "	
	echo "https:/github.com/lh3/bfc"
	echo "https:/github.com/lh3/bfc/issues/9"
	echo "https:/github.com/lh3/bfc/blob/master/correct.c#L138"
        echo " "
        exit 0
        ;;
    -V|--version)
        echo "$arg0 v1.00 (2020-07-26)"
        exit 0
        ;;
    -*) error "unrecognized option $1";;
    *)  error "unexpected non-option argument '$1'";;
    esac
    shift
done

# Argument checks
[ ! -d $INDIR ] && error "Error: Couldn't find input directory (-i)" 

# Create temporary working directory
mkdir bfc_parser_tmp
cd bfc_parser_tmp

for file in ../$INDIR/*.fq.gz; do
	# Decompress fastq file
	gunzip -c "$file" > "${file/.gz/}"
	# Extract identifier from filename
	identifier=$(basename $file | cut -d "." -f1)
	# Extract the correction info added by BFC to the sequence identifier lines
	awk -F '\t' 'NR % 4 == 1 {print $2}' "${file/.gz/}" > $identifier.corr
	# Extract the uncorrected reads from correction info
	awk -F ":" '{print $3}' $identifier.corr | grep -v "^0" | sort -n | uniq -c | awk '{t = $1; $1 = $2; $2 = t; print;}' | sort -n -r -k2 > $identifier.failures
	# Get the number of total reads and save 
	total_reads=$(cat $identifier.corr | wc -l) 
	# Get the number of uncorrected reads and save
	uncorr_reads=$(awk '{s+=$2}END{print s}' $identifier.failures)
	corr_reads_perc=$(echo "scale=2; 100-($uncorr_reads*100/$total_reads)" | bc -l)
	#Print output line by line using the extracted info
	printf "$(date)" > $identifier.bfc.summary.txt 
	printf "\nBash version: ${BASH_VERSION}\n" >> $identifier.bfc.summary.txt
	printf "\n############################################" >> $identifier.bfc.summary.txt
	printf "\n        BFC error correction summary" >> $identifier.bfc.summary.txt
	printf "\n############################################\n" >> $identifier.bfc.summary.txt
	printf "\nInput total reads: %d" $total_reads >> $identifier.bfc.summary.txt
	printf "\nCorrected reads percent: $corr_reads_perc" >> $identifier.bfc.summary.txt
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

cp bfc_parser_tmp/*.bfc.summary.txt $INDIR
rm -rf bfc_parser_tmp

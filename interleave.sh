#!/bin/bash

# Usage: bash interleave.sh -i path/to/fastq/files/directory -o path/to/output/directory --filelist path/to/tab/separated/file
#
# This script generates interleaved fastq files for a set of Illumina paired-end reads and outputs a log file.
# A tab separated file must be provided by user as an input argument (--filelist) containing an identifier, forward filename and reverse filename for each pair (see e.g. below). 
# It adds '/1' and '/2' to the sequence identifier lines by substituting first space character and combines the reads into an interleaved format using awk and paste commands (modified from https://gist.github.com/nathanhaigh/4544979)
# E.g.:
# AAAAA	Sample1_XXXXX_XXXXXXXXXX_L001_R1_001_XXXXXXXXX.fastq.gz	Sample1_XXXXX_XXXXXXXXXX_L001_R2_001_XXXXXXXXX.fastq.gz
# BBBBB	Sample2_XXXXX_XXXXXXXXXX_L001_R1_001_XXXXXXXXX.fastq.gz Sample2_XXXXX_XXXXXXXXXX_L001_R2_001_XXXXXXXXX.fastq.gz
# CCCCC	Sample3_XXXXX_XXXXXXXXXX_L001_R1_001_XXXXXXXXX.fastq.gz Sample3_XXXXX_XXXXXXXXXX_L001_R2_001_XXXXXXXXX.fastq.gz

set -o errexit
set -o nounset

# Set environment variables
INDIR=
OUTDIR=
FILELIST=
arg0="$(basename "$0" .sh)"

# Options and parser
usemsg="Usage: $arg0.sh [-h|--help][-V|--version][{-i|--indir} indir] [{-o|--outdir} outdir] [{--filelist} filelist]"
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
    -o|--outdir)
        OUTDIR="$2"
        shift
        ;;
    --filelist)
        FILELIST="$2"
        shift
        ;;
    -h|--help)
        echo "$usemsg"
        echo " "
	echo " Arguments:"
	echo "  [-i|--indir]	Specify the path to paired-end fastq files"
        echo "  [-o|--outdir]	Specify a new name for output directory"
	echo "  [--filelist]	Tab separated list containing identifiers and filenames for paired-end reads"
        echo " "
	echo "	This script generates interleaved fastq files for a set of Illumina paired-end reads and outputs a log file."
        echo "	A tab separated file must be provided by user as an input argument (--filelist) containing an identifier, forward filename and reverse filename for each pair (see e.g. below)." 
	echo "	It adds '/1' and '/2' to the sequence identifier lines by substituting first space character and combines the reads into an interleaved format using awk and paste commands (modified from https://gist.github.com/nathanhaigh/4544979)"
	echo " "
	echo "	E.g.:"
	echo "		AAAAA	Sample1_XXXXX_XXXXXXXXXX_L001_R1_001_XXXXXXXXX.fastq.gz	Sample1_XXXXX_XXXXXXXXXX_L001_R2_001_XXXXXXXXX.fastq.gz"
	echo "		BBBBB	Sample2_XXXXX_XXXXXXXXXX_L001_R1_001_XXXXXXXXX.fastq.gz	Sample2_XXXXX_XXXXXXXXXX_L001_R2_001_XXXXXXXXX.fastq.gz"
	echo "		CCCCC	Sample3_XXXXX_XXXXXXXXXX_L001_R1_001_XXXXXXXXX.fastq.gz	Sample3_XXXXX_XXXXXXXXXX_L001_R2_001_XXXXXXXXX.fastq.gz"
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
[ -d $OUTDIR ] && error "Error: A directory already exists with output directory name (-o)" 
[ ! -f $FILELIST ] && error "Error: Couldn't find fastq file list (--filelist)" 

# Check if paired-end fastq files listed in the tab separated file exist in input directory. 
while IFS=$'\t' read -r identifier forward_fname reverse_fname; do
	[ ! -f "${INDIR}/${forward_fname}" ] || [ ! -f "${INDIR}/${reverse_fname}" ] && error "Error: Missing fastq file in input directory for sample $identifier"
done < "$FILELIST"

# Create output and temporary working directories
mkdir "$OUTDIR"
mkdir interleave_tmp

# Parse the tab separated list, find the files in input directory, add "/1" and "/2" to the sequence identifier lines of forward and reverse reads, and generate interleaved fastq file for each pair by modifying the filename with identifier.
cd interleave_tmp/
echo "$(date)" | tee interleave.log
echo "bash version: ${BASH_VERSION}" | tee -a interleave.log

while IFS=$'\t' read -r identifier forward_fname reverse_fname; do 
	echo "... " | tee -a interleave.log
	echo "Processing: $identifier" | tee -a interleave.log
	forward_fpath="$(find ../$INDIR -name $forward_fname)" 
	reverse_fpath="$(find ../$INDIR -name $reverse_fname)"
	gunzip -c "$forward_fpath" | awk 'NR % 4 == 1 {gsub(" ", "/1 ",$0)}1' > "${forward_fname/.gz/}"
	n_reads=$(awk 'NR %4 ==1 {print $0}' "${forward_fname/.gz/}" | wc -l)
	gunzip -c "$reverse_fpath" | awk 'NR % 4 == 1 {gsub(" ", "/2 ",$0)}1' > "${reverse_fname/.gz/}"
	paste "${forward_fname/.gz/}" "${reverse_fname/.gz/}" | paste - - - - | awk -v OFS="\n" -v FS="\t" '{print($1,$3,$5,$7,$2,$4,$6,$8)}' | gzip -1 > "${identifier}".interleaved.fq.gz
	echo "$n_reads paired end reads merged into an interleaved fastq file for $identifier" | tee -a interleave.log
	echo "..." | tee -a interleave.log
done < "../$FILELIST" 

# Copy files and remove temporary working directory 
cp *.interleaved.fq.gz ../"$OUTDIR" 
cp interleave.log ../"$OUTDIR"
cd ../
rm -rf interleave_tmp
echo "Output fastq files are saved to directory: $OUTDIR" | tee -a "$OUTDIR"/interleave.log 

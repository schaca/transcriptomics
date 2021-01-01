#!/bin/bash

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
	echo "  [-i|--indir]	Path to the directory containing fastq files"
	echo "  [-o|--outdir]	Path to output directory (will be created if not on the path)"
	echo "  [--filelist]	Tab separated list containing identifiers and filenames for paired-end reads"
        echo " "
	echo "	This script generates interleaved fastq files for a set of Illumina paired-end reads."
        echo "	A tab separated file must be provided by user as an input argument (--filelist) containing an identifier, forward filename and reverse filename for each pair (see e.g. below)." 
	echo "	The script adds '/1' and '/2' to the sequence identifier lines by substituting first space character, and combines the reads into an interleaved format using awk and paste commands."
	echo "  Modified from https://gist.github.com/nathanhaigh/4544979"
	echo " "
	echo "	E.g.:"
	echo "		AAAAA	AAAAA_forward_read.fastq.gz	AAAAA_reverse_read.fastq.gz"
	echo "		BBBBB	BBBBB_forward_read.fastq.gz	BBBBB_reverse_read.fastq.gz"
	echo "		CCCCC	CCCCC_forward_read.fastq.gz	CCCCC_reverse_read.fastq.gz"
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
[ ! -f $FILELIST ] && error "Error: Couldn't find fastq file list (--filelist)" 

# Check if paired-end fastq files listed in the tab separated file exist in input directory. 
while IFS=$'\t' read -r identifier forward_fname reverse_fname; do
	[ ! -f "${INDIR}/${forward_fname}" ] || [ ! -f "${INDIR}/${reverse_fname}" ] && error "Error: Missing fastq file in input directory for sample $identifier"
done < "$FILELIST"

# Create output and temporary working directories
[ ! -d $OUTDIR ] && mkdir "$OUTDIR"
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

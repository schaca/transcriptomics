#!/bin/bash

# Usage: bash deinterleave.sh -i path/to/interleaved/fastq/files/directory -o path/to/output/directory
#
# This script splits interleaved fastq reads into two paired-end files. It processes all compressed fastq files in input directory, so input path should only contain interleaved fastq files.
# The script removes the pairing info on the sequence identifier lines using awk (following interleave.sh) and outputs paired-end files with extensions ".1.fq.gz" and ".2.fq.gz". 	
# Modified from: https://gist.github.com/nathanhaigh/3521724

set -o errexit
set -o nounset

# Set environment variables
INDIR=
OUTDIR=
arg0="$(basename "$0" .sh)"

# Options and parser
usemsg="Usage: $arg0.sh [-h|--help][-V|--version][{-i|--indir} indir] [{-o|--outdir} outdir]"
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
    -h|--help)
        echo "$usemsg"
        echo " "
	echo " Arguments:"
	echo "  [-i|--indir]	Path to the directory containing interleaved fastq files"
	echo "  [-o|--outdir]	Path to output directory (will be created if not on the path)"
	echo " "
	echo "	This script splits interleaved fastq reads into two paired-end files. It processes all compressed fastq files in input directory, so input path should only contain interleaved fastq files."
	echo "	The script removes the pairing info on the sequence identifier lines using awk (following interleave.sh) and outputs paired-end fastq files with extensions '.1.fq.gz' and '.2.fq.gz'."
	echo " Modified from: https://gist.github.com/nathanhaigh/3521724"
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

# Create output and working directories
[ ! -d $OUTDIR ] && mkdir "$OUTDIR"
mkdir deinterleave_tmp

# Modify the identifier lines and save the paired-end reads into two files.
cd deinterleave_tmp/
echo "$(date)" | tee deinterleave.log
echo "Bash version: ${BASH_VERSION}" | tee -a deinterleave.log
for file in ../$INDIR/*.fq.gz; do
	filename=$(basename $file)
	identifier=$(basename $file | cut -d "." -f1)
	echo "..." | tee -a deinterleave.log
	echo "Splitting reads: $identifier" | tee -a deinterleave.log
	gunzip -c $file > "${filename%.gz}"
	cat "${filename%.gz}" | awk 'NR % 4 == 1 {split($0,a,/[/]/);$0=a[1]}1' | paste - - - - - - - - | tee | cut -f 1-4 | tr "\t" "\n" | egrep -v '^$' | gzip -1 > "${identifier}".corr.1.fq.gz
	cat "${filename%.gz}" | awk 'NR % 4 == 1 {split($0,a,/[/]/);$0=a[1]}1' | paste - - - - - - - - | tee | cut -f 5-8 | tr "\t" "\n" | egrep -v '^$' | gzip -1 > "${identifier}".corr.2.fq.gz 
	n_reads=$(zcat "${identifier}".corr.1.fq.gz | awk 'NR % 4 == 1 {print $0}' | wc -l)
	echo "$n_reads paired-end reads were split into two fastq files"| tee -a deinterleave.log
done

# Copy files and remove temporary working directory 
cp *.corr.1.fq.gz ../"$OUTDIR"
cp *.corr.2.fq.gz ../"$OUTDIR"
cp deinterleave.log ../"$OUTDIR"
cd ../
rm -rf deinterleave_tmp 
echo "..." | tee -a "$OUTDIR"/deinterleave.log
echo "Output files are saved to directory: $OUTDIR" | tee -a "$OUTDIR"/deinterleave.log




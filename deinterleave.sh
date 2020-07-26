#!/bin/bash

# Usage: bash deinterleave.sh -i path/to/interleaved/fastq/files/directory -o path/output/directory
#
# This script splits interleaved fastq reads into a set of paired end reads. It removes the extra info on the header lines to avoid downstream issues, and outputs two files with extensions "....1.fq.gz" and "....2.fq.gz"
#
# The code to split the reads is modified from https://gist.github.com/nathanhaigh/3521724

set -o errexit
set -o nounset
exec 1>deinterleave.log.out 2>&1

# Option parser
DEBUG=0
while [ $# -gt 0 ]; do
    case "$1" in
        -i|--indir)
            in_dir="$2"
            shift 2
            ;;
        -o|--outdir)
            out_dir="$2"
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

echo "$(date)"
echo "Current bash version: ${BASH_VERSION}"

# Argument folder and file check
[ ! -d $in_dir ] && echo "Error: invalid input directory path (-i)" && exit 1
[ -d $out_dir ] && echo "Error: a directory already exists on the path with output name (-o)" && exit 1

# Create output and temporary working directory
mkdir -p $out_dir
mkdir -p deinterleave_tmp

cd deinterleave_tmp/
for file in ../$in_dir/*.fq.gz; do
	filename=$(basename $file)
	samplecode=$(basename $file | cut -d "." -f1)
	echo "Splitting reads for sample: $samplecode"
	gunzip -c $file > "${filename%.gz}"
	cat "${filename%.gz}" | awk 'NR % 4 == 1 {split($0,a,/[/]/);$0=a[1]}1' | paste - - - - - - - - | tee | cut -f 1-4 | tr "\t" "\n" | egrep -v '^$' | gzip -1 > "${samplecode}".corr.1.fq.gz
	cat "${filename%.gz}" | awk 'NR % 4 == 1 {split($0,a,/[/]/);$0=a[1]}1' | paste - - - - - - - - | tee | cut -f 5-8 | tr "\t" "\n" | egrep -v '^$' | gzip -1 > "${samplecode}".corr.2.fq.gz 
	n_reads=$(zcat "${samplecode}".corr.1.fq.gz | awk 'NR % 4 == 1 {print $0}' | wc -l)
	echo "$n_reads paired-end reads were split into two fastq files"
done 
cd ../

echo "Output files are saved to directory: $out_dir"
cp deinterleave_tmp/*.corr.1.fq.gz $out_dir
cp deinterleave_tmp/*.corr.2.fq.gz $out_dir
[[ "$PWD" != "$out_dir" ]] && mv ./deinterleave.log.out $out_dir
#rm -rf deinterleave_tmp 




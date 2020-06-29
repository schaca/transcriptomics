#!/bin/bash

# Usage: bash deinterleave.sh path/to/input/fastq/folder path/to/output/folder
#
# This script deinterleaves compressed FASTQ files containing paired end reads, and outputs two files.
#
# https://gist.github.com/nathanhaigh/3521724

in_dir=$1
out_dir=$2
mkdir -p $out_dir
mkdir work_dir

for file in $in_dir/*.gz; do
	filename=$(basename $file)
	samplecode=$(basename $file | cut -d "." -f1)
	gunzip -c $file > work_dir/"${filename%.gz}"
	cat work_dir/"${filename%.gz}" | sed 's/\t.*$//' | paste - - - - - - - - | tee | cut -f 1-4 | tr "\t" "\n" | egrep -v '^$' | gzip > work_dir/${samplecode}.1.fq.gz
	cat work_dir/"${filename%.gz}" | sed 's/\t.*$//' | paste - - - - - - - - | tee | cut -f 5-8 | tr "\t" "\n" | egrep -v '^$' | gzip > work_dir/${samplecode}.2.fq.gz
done 

cp work_dir/*.1.fq.gz $out_dir/
cp work_dir/*.2.fq.gz $out_dir/
rm -rf work_dir




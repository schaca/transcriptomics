#!/bin/bash

# Usage: interleave.sh path/to/input/fastq/folder path/to/output/folder path/to/tab/separated/file
#
# This script adds read pairing info to paired end Illumina reads and outputs a single interleaved fastq file in compressed format.
# It requires three arguments: an input folder of fastq files; an output folder (going to be created if not done already); and a tab separated file listing sample code, forward fastq filename and reverse fastq filename.
# E.g.:
# AAAAA	Sample1_XXXXX_XXXXXXXXXX_L001_R1_001_XXXXXXXXX.fastq.gz	Sample1_XXXXX_XXXXXXXXXX_L001_R2_001_XXXXXXXXX.fastq.gz
# BBBBB	Sample2_XXXXX_XXXXXXXXXX_L001_R1_001_XXXXXXXXX.fastq.gz Sample2_XXXXX_XXXXXXXXXX_L001_R2_001_XXXXXXXXX.fastq.gz
# CCCCC	Sample3_XXXXX_XXXXXXXXXX_L001_R1_001_XXXXXXXXX.fastq.gz Sample3_XXXXX_XXXXXXXXXX_L001_R2_001_XXXXXXXXX.fastq.gz
#
# Read pairing info added following https://oyster-river-protocol.readthedocs.io/en/v2/bfc_pairing.html
# Interleaved fastq produced following https://gist.github.com/nathanhaigh/4544979

in_dir=$1
out_dir=$2
mkdir -p $out_dir
mkdir work_dir

while IFS=$'\t' read -r sample_code forward_fname reverse_fname; do 
	forward_fpath="$in_dir/$forward_fname"
	reverse_fpath="$in_dir/$reverse_fname"
	gunzip -c "$forward_fpath" | sed 's_ _/1 _g' > work_dir/"${forward_fname/.gz/}"
	gunzip -c "$reverse_fpath" | sed 's_ _/2 _g' > work_dir/"${reverse_fname/.gz/}"
	paste work_dir/"${forward_fname/.gz/}" work_dir/"${reverse_fname/.gz/}" | paste - - - - | awk -v OFS="\n" -v FS="\t" '{print($1,$3,$5,$7,$2,$4,$6,$8)}' | gzip > work_dir/$sample_code.interleaved.fq.gz
done < $3

cp work_dir/*.interleaved.fq.gz $out_dir/
rm -rf work_dir




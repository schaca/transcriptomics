#!/bin/bash

# Usage: bash interleave.sh -i path/to/fastq/files/directory -o path/to/output/directory --filelist path/to/tab/separated/file
#
# This script generates interleaved fastq files for multiple sets of Illumina paired end reads. A tab separated file must be prepared by user as an argument to the script (--filelist), containing a sample code, forward filename and reverse filename for each pair of reads. 
# E.g.:
# AAAAA	Sample1_XXXXX_XXXXXXXXXX_L001_R1_001_XXXXXXXXX.fastq.gz	Sample1_XXXXX_XXXXXXXXXX_L001_R2_001_XXXXXXXXX.fastq.gz
# BBBBB	Sample2_XXXXX_XXXXXXXXXX_L001_R1_001_XXXXXXXXX.fastq.gz Sample2_XXXXX_XXXXXXXXXX_L001_R2_001_XXXXXXXXX.fastq.gz
# CCCCC	Sample3_XXXXX_XXXXXXXXXX_L001_R1_001_XXXXXXXXX.fastq.gz Sample3_XXXXX_XXXXXXXXXX_L001_R2_001_XXXXXXXXX.fastq.gz
#
# Interleaved fastq produced following https://gist.github.com/nathanhaigh/4544979

set -o errexit
set -o nounset
exec 1>interleave.log.out 2>&1

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
    	--filelist)
	    fastq_list="$2"
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
echo "Bash version: ${BASH_VERSION}\n"

# Argument directory and file check
[ ! -d $in_dir ] && echo "Error: Couldn't find input directory (-i)" && exit 1
[ -d $out_dir ] && echo "Error: A directory already exists with output directory name (-o)" && exit 1
[ ! -f $fastq_list ] && echo "Error: Couldn't find fastq file list (--filelist)" && exit 1

# Create output and temporary working directory
mkdir -p $out_dir
mkdir -p interleave_tmp

# Check if paired-end fastq files listed in the tab separated file exist in input directory. 
while IFS=$'\t' read -r sample_code forward_fname reverse_fname; do
	[[ ! -f "${in_dir}/${forward_fname}" ]] || [[ ! -f "${in_dir}/${reverse_fname}" ]] && echo "Error: Missing fastq file in input directory for sample $sample_code" && exit 1 
done < "$fastq_list"

# Parse the tab separated list, find the files in input directory, add "/1" and "/2" to the header line of forward and reverse reads and generate interleaved fastq file for each sample
cd interleave_tmp/
while IFS=$'\t' read -r sample_code forward_fname reverse_fname; do 
	echo "Processing sample: $sample_code"
	forward_fpath="$(find ../$in_dir -name $forward_fname)" 
	reverse_fpath="$(find ../$in_dir -name $reverse_fname)"
	gunzip -c "$forward_fpath" | awk 'NR % 4 == 1 {gsub(" ", "/1 ",$0)}1' > "${forward_fname/.gz/}"
	n_reads=$(awk 'NR %4 ==1 {print $0}' "${forward_fname/.gz/}" | wc -l)
	gunzip -c "$reverse_fpath" | awk 'NR % 4 == 1 {gsub(" ", "/2 ",$0)}1' > "${reverse_fname/.gz/}"
	paste "${forward_fname/.gz/}" "${reverse_fname/.gz/}" | paste - - - - | awk -v OFS="\n" -v FS="\t" '{print($1,$3,$5,$7,$2,$4,$6,$8)}' | gzip -1 > "${sample_code}".interleaved.fq.gz
	echo "$n_reads paired end reads merged into an interleaved fastq file for $sample_code"
done < "../$fastq_list" 
cd ../

# Remove the temporary working directory a
echo "Output fastq files are saved to directory: $out_dir"
cp interleave_tmp/*.interleaved.fq.gz $out_dir/
[[ "$PWD" != "$out_dir" ]] && mv ./interleave.log.out $out_dir/ 
rm -rf interleave_tmp




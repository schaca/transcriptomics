#!/bin/bash

# Usage: bash extract_CDS_by_orthogroup.sh -i path/to/CDS/fasta/files --orthogroups_tsv path/to/Orthogroups.tsv --orthogroups_ids path/to/orthogroups/list --sample_ids path/to/sample/ids -o path/to/output/directory
#
# This script extracts coding sequences for a provided list of OrthoFinder orthogroups.
# It requires the path to the directory containing coding sequences, "Orthogroups.tsv" file from OrthoFinder results, a list of orthogroups to extract coding sequences for (for SCO: Orthogroups_SingleCopyOrthologues.txt), and a tab delimited list linking sample IDs (headers in orthogroups.tsv) with '.cds' files (see e.g. below).
# The script first removes the extra info on the header lines of '.cds' files by removing everything after first space character. Then it extracts the transcript ID's from Orthogroups.tsv file for a given set of orthogroups, appends the corresponding coding sequences and saves a single fasta file for each orthogroup.
# E.g.:
#   Sample1     Sample1.trinity.Trinity.fasta.transdecoder.cds
#   Sample2     Sample2.trinity.Trinity.fasta.transdecoder.cds
#   Sample3     Sample3.trinity.Trinity.fasta.transdecoder.cds

set -o errexit
set -o nounset

# Set environment variables
INDIR=
INFILE1=
INFILE2=
INFILE3=
OUTDIR=
arg0="$(basename "$0" .sh)"

# Options and parser
usemsg="Usage: $arg0.sh [-h|--help][-V|--version][{-i|--CDS} indir] [{--orthogroups_tsv} orthogroups.tsv] [{--orthogroups_ids} orthogroups_ids] [{--sample_ids} sample_ids] [{-o|--outdir} outdir]"
usage() { echo "$usemsg" >&2; exit 1; }
error() { echo "$0 $*" >&2; usage; }

[[ $# -eq 0 ]] && error
while [ $# -gt 0 ] 
do
    case "$1" in
    -i|--CDS)
        INDIR="$2"
        shift
        ;;
    --orthogroups_tsv)
        INFILE1="$2"
        shift
        ;;
    --orthogroups_ids)
        INFILE2="$2"
        shift
        ;;
    --sample_ids)
        INFILE3="$2"
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
        echo "  [-i|--CDS]      Path to the directory containing cds files"
        echo "  [--orthogroups_tsv] Path to Orthogroups.tsv"
        echo "  [--orthogroups_ids] A list of orthogroups to extract CDS for"
        echo "  [--sample_ids] A tab delimited file linking headers in the Orthogroups.tsv file with CDS files"
        echo "  [-o|--output]   Path to output directory"
        echo " "
	echo " This script extracts coding sequences for a provided list of OrthoFinder orthogroups."
	echo " It requires the path to the directory containing coding sequences, 'Orthogroups.tsv' file from OrthoFinder results, a list of orthogroups to extract coding sequences for (for SCO: Orthogroups_SingleCopyOrthologues.txt), and a tab delimited list linking sample IDs (headers in orthogroups.tsv) with '.cds' files (see e.g. below)."
	echo " The script first removes the extra info on the header lines of '.cds' files by removing everything after first space character. Then it extracts the transcript ID's from Orthogroups.tsv file for a given set of orthogroups, appends the corresponding coding sequences and saves a single fasta file for each orthogroup."
	echo " E.g.:"
	echo "   Sample1     Sample1.trinity.Trinity.fasta.transdecoder.cds"
	echo "   Sample2     Sample2.trinity.Trinity.fasta.transdecoder.cds"
	echo "   Sample3     Sample3.trinity.Trinity.fasta.transdecoder.cds"
        exit 0
        ;;
    -V|--version)
        echo "$arg0 v1.00 (2020-10-21)"
        exit 0
        ;;
    -*) error "unrecognized option $1";;
    *)  error "unexpected non-option argument '$1'";;
    esac
    shift
done

# Argument checks
[ ! -d "$INDIR" ] && error "Error: Couldn't find coding sequences (-i)"
[ ! -f "$INFILE1" ] && error "Error: Couldn't find Orthogroups.tsv file (--orthogroups_tsv)"
[ ! -f "$INFILE2" ] && error "Error: Couldn't find orthogroup ids to extract (--orthogroups_ids)"
[ ! -f "$INFILE3" ] && error "Error: Couldn't find tab delimited file linking sample ID's with '.cds' files"

## Check if '.cds' files listed in the tab separated file exist in input directory. 
while IFS=$'\t' read -r sample_id fname; do
        [ ! -f "${INDIR}/${fname}" ] && error "Error: Missing CDS file in input directory for sample $fname"
done < "$INFILE3"

## Create output and temporary working directories
[ ! -d "$OUTDIR" ] && mkdir "$OUTDIR"
mkdir extract_CDS_tmp

## Parse the tab separated list, find the files in input directory, add '/1' and '/2' to the sequence identifier lines of forward and reverse reads, and generate interleaved fastq file for each pair by modifying the filename with identifier.
cd extract_CDS_tmp
date | tee extract_CDS.log
echo "bash version: ${BASH_VERSION}" | tee -a extract_CDS.log

## Read tab separated sample id's list, remove the extra info on the header lines of matching '.cds' files and save to the temporary working directory.
while IFS=$'\t' read -r sample_id fname; do
        awk '/^>/ {split($0,a,/ /);$0=a[1]}1' "../${INDIR}/${fname}" > "$sample_id".cds
done < "../$INFILE3"

## Extract the transcripts from Orthogroups.tsv file for given orthogroups
sed 's/.fa//g' "../$INFILE2" > orthogroups_list
grep -f orthogroups_list "../$INFILE1" > single_copy_orthogroups.tsv

# Extract headers and save sample_ids (headers) from Orthogroups.tsv, and remove , reads for each orthogroup from each sample, append and save to output directory.  
sampleID1=$(head -1 "../$INFILE1" | awk -F "\t" '{print$2}')
sampleID2=$(head -1 "../$INFILE1" | awk -F "\t" '{print$3}')
sampleID3=$(head -1 "../$INFILE1" | awk -F "\t" '{print$4}')
sampleID4=$(head -1 "../$INFILE1" | awk -F "\t" '{print$5}')

# Read Orthogroups.tsv file, extract headers and save sample_ids, reads for each orthogroup from each sample, append and save to output directory.  
while IFS=$'\t' read -r orthogroup sample1 sample2 sample3 sample4; do
        echo "... " | tee -a extract_CDS.log
        echo "Processing: $orthogroup" | tee -a extract_CDS.log
        echo "... " | tee -a extract_CDS.log
        echo "$sample1" | tr , "\n" | sed '/^[[:space:]]*$/d' | sed 's/^ *//g'  > sample1.transcript_idlist
        echo "$sample2" | tr , "\n" | sed '/^[[:space:]]*$/d' | sed 's/^ *//g'  > sample2.transcript_idlist
        echo "$sample3" | tr , "\n" | sed '/^[[:space:]]*$/d' | sed 's/^ *//g'  > sample3.transcript_idlist
        echo "$sample4" | tr , "\n" | sed '/^[[:space:]]*$/d' | sed 's/^ *//g'  > sample4.transcript_idlist
        awk 'NR==1{printf $0"\t";next}{printf /^>/ ? "\n"$0"\t" : $0}' "$sampleID1".cds | awk -F "\t" 'BEGIN{while((getline k < "sample1.transcript_idlist")>0)i[k]=1}{gsub("^>","",$0); if(i[$1]){print ">"$1"\n"$2}}' > "$orthogroup".fa
        awk 'NR==1{printf $0"\t";next}{printf /^>/ ? "\n"$0"\t" : $0}' "$sampleID2".cds | awk -F "\t" 'BEGIN{while((getline k < "sample2.transcript_idlist")>0)i[k]=1}{gsub("^>","",$0); if(i[$1]){print ">"$1"\n"$2}}' >> "$orthogroup".fa
        awk 'NR==1{printf $0"\t";next}{printf /^>/ ? "\n"$0"\t" : $0}' "$sampleID3".cds | awk -F "\t" 'BEGIN{while((getline k < "sample3.transcript_idlist")>0)i[k]=1}{gsub("^>","",$0); if(i[$1]){print ">"$1"\n"$2}}' >> "$orthogroup".fa
        awk 'NR==1{printf $0"\t";next}{printf /^>/ ? "\n"$0"\t" : $0}' "$sampleID4".cds | awk -F "\t" 'BEGIN{while((getline k < "sample4.transcript_idlist")>0)i[k]=1}{gsub("^>","",$0); if(i[$1]){print ">"$1"\n"$2}}' >> "$orthogroup".fa
        echo "Coding sequences saved to ${orthogroup}.fa" | tee -a extract_CDS.log
        rm *idlist
done < single_copy_orthogroups.tsv

# Copy files to output directory and remove temporary working directory 
cp *.fa ../"$OUTDIR"
cp extract_CDS.log ../"$OUTDIR"
cd ../
rm -rf extract_CDS_tmp
echo "Output fasta files are saved to directory: $OUTDIR" | tee -a "$OUTDIR"/extract_CDS.log

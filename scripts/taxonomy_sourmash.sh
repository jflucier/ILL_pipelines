#!/bin/bash

set -e

help_message () {
	echo ""
	echo "Usage: taxonomic_profile.sample.sh -s sample_name -o /path/to/out [--db] [--trimmomatic_options \"trim options\"] [--bowtie2_options \"bowtie2 options\"]"
	echo "Options:"

	echo ""
	echo "	-s STR	sample name"
    echo "	-o STR	path to output dir"
    echo "	-tmp STR	path to temp dir (default output_dir/temp)"
    echo "	-t	# of threads (default 8)"
    echo "	-m	memory (default 40G)"
    echo "	-fq1	path to fastq1"
    echo "	-fq2	path to fastq2"
    echo "	--SM_db	sourmash databases directory path (default /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/SM_db)"
    echo "	--SM_db_prefix	sourmash database prefix, allowing wildcards (default gtdb-rs207)"
	echo "	--kmer	choice of k-mer, dependent on database choices (default k21, make sure to have them available)"

    echo ""
    echo "  -h --help	Display help"

	echo "";
}

export EXE_PATH=$(dirname "$0")

# initialisation
threads="8"
mem="40G"
sample="false";
out="false";
tmp="false";
fq1="false";
fq2="false";
SM_db="/nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/sourmash_db"
SM_db_prefix="gtdb-rs207"
kmer="k21"

# load in params
SHORT_OPTS="ht:m:o:s:fq1:fq2:tmp:"
LONG_OPTS='help,SM_db,SM_db_prefix,kmer'

OPTS=$(getopt -o $SHORT_OPTS --long $LONG_OPTS -- "$@")
# make sure the params are entered correctly
if [ $? -ne 0 ];
then
    help_message;
    exit 1;
fi

# loop through input params
while true; do
    # echo $1
	case "$1" in
        -h | --help) help_message; exit 1; shift 1;;
        -t) threads=$2; shift 2;;
        -tmp) tmp=$2; shift 2;;
        -m) mem=$2; shift 2;;
        -s) sample=$2; shift 2;;
        -o) out=$2; shift 2;;
        -fq1) fq1=$2; shift 2;;
        -fq2) fq2=$2; shift 2;;
		--SM_db) SM_db=$2; shift 2;;
        --SM_db_prefix) SM_db_prefix=$2; shift 2;;
        --kmer) kmer=$2; shift 2;;
        --) help_message; exit 1; shift; break ;;
		*) break;;
	esac
done

if [ "$sample" = "false" ]; then
    echo "Please provide a sample name."
    help_message; exit 1
else
    echo "## Sample name: $sample"
fi

if [ "$out" = "false" ]; then
    echo "Please provide an output path"
    help_message; exit 1
else
    mkdir -p $out
    echo "## Results wil be stored to this path: $out/"
fi

if [ "$tmp" = "false" ]; then
    tmp=$out/temp
    mkdir -p $tmp
    echo "## No temp folder provided. Will use: $tmp"
fi

echo "analysing sample $sample containment with Sourmash against ${SM_db_prefix}.$kmer index"
echo "fastq1 path: $fq1"
echo "fastq2 path: $fq2"

fq1_name=$(basename $fq1)
fq2_name=$(basename $fq2)

echo "upload fastq1 to $tmp/$fq1_name"
cp $fq1 $tmp/$fq1_name

echo "upload fastq2 to $tmp/$fq2_name"
cp $fq2 $tmp/$fq2_name

echo "upload Sourmash db to $tmp"
for file in ${SM_db}/${SM_db_prefix}*.${kmer}.zip; do \
	cp -r "$file" $tmp; 
done
for file in ${SM_db}/${SM_db_prefix}*lineages.sqldb; do \
	cp -r "$file" $tmp; 
done

### Sourmash
echo "loading Sourmash env"
conda activate sourmash
module load StdEnv/2020 mugqic/bowtie2/2.3.5

mkdir $tmp/${sample}
echo "...generate sample fracminhash sketch with sourmash sketch"
sourmash sketch dna \
	-p k=$kmer,scaled=1000,abund \
	--merge $sample \
	-o $tmp/${sample}/${sample}.${kmer}.sig \
	$tmp/${fq1_name} \
	$tmp/${fq2_name}

echo "...determine metagenome composition using sourmash gather"
sourmash gather \
	$tmp/${sample}/${sample}.${kmer}.sig \
	$tmp/${SM_db_prefix}*-${kmer}.zip \
	-o $tmp/${sample}/${sample}.${kmer}.csv

echo "...assign taxonomy using sourmash taxonomy"
sourmash tax annotate \
	-g $tmp/${sample}/${sample}.${kmer}.csv \
	-t $tmp/${SM_db_prefix}*lineages.sqldb \
	-o $tmp/${sample}

echo "...summarise results to species level"
mkdir $tmp/${sample}/
sourmash tax metagenome \
	-g $tmp/${sample}/${sample}.${kmer}.with-lineages.csv \
	--rank species \
	-t $tmp/${SM_db_prefix}*lineages.sqldb \
	-o $tmp/${sample}
				
echo "copying all results to $out"
mkdir -p ${out}/taxSM_${SM_db_prefxi}_${kmer} && cp -fr $tmp/${sample}/* $_

echo "taxonomic profile of ${sample} completed!"

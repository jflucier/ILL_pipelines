#!/bin/bash

set -e

help_message () {
	echo ""
	echo "Usage: preprocess.kneaddata.sh -s sample_name -o /path/to/out [--db] [--trimmomatic_options \"trim options\"] [--bowtie2_options \"bowtie2 options\"]"
	echo "Options:"

	echo ""
	echo "	-s STR	sample name"
    echo "	-o STR	path to output dir"
    echo "	-tmp STR	path to temp dir (default output_dir/temp)"
    echo "	-t	# of threads (default 8)"
    echo "	-m	memory (default 40G)"
    echo "	-fq1	path to fastq1"
    echo "	-fq2	path to fastq2"
    echo "	--db	kneaddata database path (default /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/host_genomes/GRCh38_index/grch38_1kgmaj)"
    echo "	--trimmomatic_options	options to pass to trimmomatic (default ILLUMINACLIP:/cvmfs/soft.mugqic/CentOS6/software/trimmomatic/Trimmomatic-0.39/adapters/TruSeq3-PE-2.fa:2:30:10 SLIDINGWINDOW:4:30 MINLEN:100)"
    echo "	--bowtie2_options	options to pass to trimmomatic (default --very-sensitive-local)"

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
db="/nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/host_genomes/GRCh38_index/grch38_1kgmaj"
trimmomatic_options="ILLUMINACLIP:/cvmfs/soft.mugqic/CentOS6/software/trimmomatic/Trimmomatic-0.39/adapters/TruSeq3-PE-2.fa:2:30:10 SLIDINGWINDOW:4:30 MINLEN:100"
bowtie2_options="--very-sensitive-local"

##### need to bypass getopt because bowtie parameters passing has -- #####

# # load in params
# SHORT_OPTS="ht:m:o:s:fq1:fq2:tmp:"
# LONG_OPTS='help,db,trimmomatic_options,bowtie2_options'

# OPTS=$(getopt -o $SHORT_OPTS --long $LONG_OPTS -- "$@")
# # make sure the params are entered correctly
# if [ $? -ne 0 ];
# then
#     help_message;
#     exit 1;
# fi

# loop through input params
while true; do
    # echo "$1=$2"
	case "$1" in
        -h | --help) help_message; exit 1; shift 1;;
        -t) threads=$2; shift 2;;
        -tmp) tmp=$2; shift 2;;
        -m) mem=$2; shift 2;;
        -s) sample=$2; shift 2;;
        -o) out=$2; shift 2;;
        -fq1) fq1=$2; shift 2;;
        -fq2) fq2=$2; shift 2;;
		--db) db=$2; shift 2;;
        --trimmomatic_options) trimmomatic_options=$2; shift 2;;
        --bowtie2_options) bowtie2_options=$2; shift 2;;
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

echo "analysing sample $sample with metawrap"
echo "fastq1 path: $fq1"
echo "fastq2 path: $fq2"

fq1_name=$(basename $fq1)
fq2_name=$(basename $fq2)


echo "upload fastq1 to $tmp/"
cp $fq1 $tmp/$fq1_name
echo "upload fastq2 to $tmp"
cp $fq2 $tmp/$fq2_name

### Preproc
source /project/def-ilafores/common/kneaddata/bin/activate

echo "running kneaddata. kneaddata ouptut: $tmp/"
###### pas de decontamine, output = $tmp/${sample}/*repeats* --> peut changer etape pour fastp et cutadapt
kneaddata -v \
--log ${out}/kneaddata-${sample}.log \
--input $tmp/${fq1_name} \
--input $tmp/${fq2_name} \
-db ${db} \
--bowtie2-options="${bowtie2_options}" \
-o $tmp/ \
--output-prefix ${sample} \
--threads ${threads} \
--max-memory ${mem} \
--trimmomatic-options="${trimmomatic_options}" \
--run-fastqc-start \
--run-fastqc-end

echo "deleting kneaddata uncessary files"
rm $tmp/${sample}*repeats* $tmp/${sample}*trimmed*

echo "moving contaminants fastqs to subdir"
mkdir -p $tmp/${sample}_contaminants
mv $tmp/${sample}*contam*.fastq $tmp/${sample}_contaminants/

echo "concatenate paired output, for HUMAnN single-end run"
cat $tmp/${sample}_paired_1.fastq $tmp/${sample}_paired_2.fastq > $tmp/${sample}_cat-paired.fastq

echo "copying all kneaddata results to $out"
cp -fr $tmp/${sample}* $out/

echo "done ${sample}"

#!/bin/bash

set -e

help_message () {
	echo ""
	echo "Usage: quantify_bins.salmon.sh [-tmp /path/tmp] [-t threads] -bins_tsv all_genome_bins_path_regex -drep /path/to/drep_output -o /path/to/out -a algorithm -p_ani value -s_ani value -cov value -comp value -con value "
	echo "Options:"

	echo ""
	echo "	-tmp STR	path to temp dir (default output_dir/temp)"
	echo "	-t	# of threads (default 8)"
	echo "	-sample_tsv	A 3 column tsv of samples. Columns should be sample_name<tab>/path/to/fastq1<tab>/path/to/fastq2. No headers! HINT: preprocess step generates this file"
    echo "	-drep STR	dereplicated genome path (drep output directory). See dereplicate_bins.dRep.sh for more information."
    echo "	-o STR	path to output dir"
    echo ""
    echo "  -h --help	Display help"

	echo "";
}

export EXE_PATH=$(dirname "$0")

# initialisation
threads="8"
sample_tsv="false"
out="false"
tmp="false"
drep="false"

# load in params
SHORT_OPTS="ht:sample_tsv:o:tmp:drep:"
LONG_OPTS='help'

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
        -o) out=$2; shift 2;;
        -sample_tsv) sample_tsv=$2; shift 2;;
        -drep) drep=$2; shift 2;;
        --) help_message; exit 1; shift; break ;;
		*) break;;
	esac
done

if [ "$sample_tsv" = "false" ]; then
    echo "Please provide a 3 column tsv of samples. Columns should be sample_name<tab>/path/to/fastq1<tab>/path/to/fastq2. No headers!"
    help_message; exit 1
else
	echo "## Samples tsv path: $sample_tsv"
fi

if [ "$drep" = "false" ]; then
    echo "Please provide a dereplicated genome path (drep output directory). See dereplicate_bins.dRep.sh for more information."
    help_message; exit 1
else
	echo "## Dereplicated genome path: $drep"
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

echo "## Number of threads: $threads"

echo "Generate salmon index from $drep"
mkdir -p $tmp/salmon_index
cat $drep/*.fa > $tmp/salmon_index/bin_assembly.fa
assembly=$tmp/salmon_index/bin_assembly.fa
singularity exec --writable-tmpfs \
-B $tmp:$tmp \
-e ${EXE_PATH}/../containers/salmon.1.9.0.sif \
salmon index -p $threads -t $tmp/salmon_index/bin_assembly.fa -i $tmp/salmon_index

echo "upload bins to $tmp/bins"
mdkir -p $tmp/quant_bins/alignment_files
mdkir $tmp/data
cat $sample_tsv | while  IFS=$'\t' read  -r name f1 f2
do

    echo "copying fastq $f1 on node"
    nf1=$(basename $f1)
    cp $f1 $tmp/data/${nf1}
    echo "copying fastq $f2 on node"
    nf2=$(basename $f2)
    cp $f2 $tmp/data/${nf2}

    echo "running salmon on ${name}"
    singularity exec --writable-tmpfs \
    -B $tmp:$tmp \
    -e ${EXE_PATH}/../containers/salmon.1.9.0.sif \
    salmon quant \
    -i $tmp/salmon_index \
    --libType IU \
    -1 $tmp/data/${nf1} -2 $tmp/data/${nf2} \
    -o $tmp/quant_bins/alignment_files/${name}.quant \
    --meta -p $threads
done

curr_path=$(pwd)
cd $tmp/quant_bins/alignment_files

singularity exec --writable-tmpfs \
-H $tmp/quant_bins/alignment_files \
-e ${EXE_PATH}/../containers/metawrap.1.3.sif \
/miniconda3/envs/metawrap-env/bin/metawrap-scripts/summarize_salmon_files.py

cd $curr_path
mkdir $tmp/quant_bins/quant_files
for f in $(ls $tmp/quant_bins/alignment_files/ | grep .quant.counts);
do
    mv $tmp/quant_bins/alignment_files/$f $tmp/quant_bins/quant_files/
done

n=$(ls $tmp/quant_bins/quant_files/ | grep counts | wc -l)
echo "There were $n samples detected. Making abundance table"
assembly=$index/bin_assembly.fa
singularity exec --writable-tmpfs \
-B $tmp:$tmp \
-B $drep:$drep \
-B $index:$index \
-e ${EXE_PATH}/../containers/metawrap.1.3.sif \
/miniconda3/envs/metawrap-env/bin/metawrap-scripts/split_salmon_out_into_bins.py \
$tmp/quant_bins/quant_files/ \
$drep \
$index/bin_assembly.fa > $tmp/quant_bins/bin_abundance_table.tab
echo "Average bin abundance table stored in quant_bins/abundance_table.tab"

singularity exec --writable-tmpfs \
-B $tmp:$tmp \
-e ${EXE_PATH}/../containers/metawrap.1.3.sif \
/miniconda3/envs/metawrap-env/bin/metawrap-scripts/make_heatmap.py \
$tmp/quant_bins/bin_abundance_table.tab \
$tmp/quant_bins/bin_abundance_heatmap.png

echo "copying drep results back to $out/"
mkdir -p $out/
cp -r $tmp/quant_bins $out

echo "quantification pipeline done"

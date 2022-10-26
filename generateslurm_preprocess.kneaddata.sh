#!/bin/bash

set -e

help_message () {
	echo ""
	echo "Usage: generateslurm_preprocess.kneaddata.sh --sample_tsv /path/to/tsv --out /path/to/out [--db] [--trimmomatic_options \"trim options\"] [--bowtie2_options \"bowtie2 options\"]"
	echo "Options:"

	echo ""
	echo "	--sample_tsv STR	path to sample tsv (3 columns: sample name<tab>fastq1 path<tab>fastq2 path)"
    echo "	--out STR	path to output dir"
    echo "	--db	path(s) to contaminant genome(s) (default /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/host_genomes/GRCh38_index/grch38_1kgmaj)"
    echo "	--trimmomatic_adapters	adapter file default (default ILLUMINACLIP:/cvmfs/soft.mugqic/CentOS6/software/trimmomatic/Trimmomatic-0.39/adapters/TruSeq3-PE-2.fa:2:30:10)"
    echo "	--trimmomatic_options	quality trimming options (default SLIDINGWINDOW:4:30 MINLEN:100)"
    echo "	--bowtie2_options	options to pass to trimmomatic (default --very-sensitive-local)"

    echo ""
    echo "Slurm options:"
    echo "	--slurm_alloc STR	slurm allocation (default def-ilafores)"
    echo "	--slurm_log STR	slurm log file output directory (default to output_dir/logs)"
    echo "	--slurm_email \"your@email.com\"	Slurm email setting"
    echo "	--slurm_walltime STR	slurm requested walltime (default 24:00:00)"
    echo "	--slurm_threads INT	slurm requested number of threads (default 24)"
    echo "	--slurm_mem STR	slurm requested memory (default 30G)"

    echo ""
    echo "  -h --help	Display help"

	echo "";
}

export EXE_PATH=$(dirname "$0")

# initialisation
alloc="def-ilafores"
email="false"
walltime="24:00:00"
threads="24"
mem="30G"
log="false"

sample_tsv="false";
out="false";
db="/nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/host_genomes/GRCh38_index/grch38_1kgmaj"
trimmomatic_options="SLIDINGWINDOW:4:30 MINLEN:100"
trimmomatic_adapters="ILLUMINACLIP:/cvmfs/soft.mugqic/CentOS6/software/trimmomatic/Trimmomatic-0.39/adapters/TruSeq3-PE-2.fa:2:30:10"
bowtie2_options="--very-sensitive-local"

# load in params
SHORT_OPTS="h"
LONG_OPTS='help,slurm_alloc,slurm_log,slurm_email,slurm_walltime,slurm_threads,slurm_mem,\
sample_tsv,out,db\
trimmomatic_options,trimmomatic_adapters,bowtie2_options'

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
        --slurm_alloc) alloc=$2; shift 2;;
        --slurm_log) log=$2; shift 2;;
        --slurm_email) email=$2; shift 2;;
        --slurm_walltime) walltime=$2; shift 2;;
        --slurm_threads) threads=$2; shift 2;;
        --slurm_mem) mem=$2; shift 2;;
        --sample_tsv) sample_tsv=$2; shift 2;;
        --out) out=$2; shift 2;;
		--db) db=$2; shift 2;;
        --trimmomatic_options) trimmomatic_options=$2; shift 2;;
        --trimmomatic_adapters) trimmomatic_adapters=$2; shift 2;;
        --bowtie2_options) bowtie2_options=$2; shift 2;;
        --) help_message; exit 1; shift; break ;;
		*) break;;
	esac
done

if [ "$sample_tsv" = "false" ]; then
    echo "Please provide a sample list file."
    help_message; exit 1
elif [[ ! -f $sample_tsv ]]
then
    echo "Sample file ${sample_tsv} does not exist!"
else
    echo "## Will use sample file: $sample_tsv"
fi

if [ "$out" = "false" ]; then
    echo "Please provide an output path"
    help_message; exit 1
elif [[ ! -d "$out" ]]; then
    echo "## Output path $out doesnt exist. Will create it!"
fi

mkdir -p $out

echo "## Results wil be stored to this path: $out"

if [ "$log" = "false" ]; then
    log=$out/logs
    echo "## Slurm output path not specified, will output logs in: $log"
else
    echo "## Will output logs in: $log"
fi


mkdir -p $log

echo "outputting preprocess slurm script to ${out}/preprocess.kneaddata.slurm.sh"
echo '#!/bin/bash' > ${out}/preprocess.kneaddata.slurm.sh
echo '

#SBATCH --mail-type=END,FAIL
#SBATCH -D '${out}'
#SBATCH -o '${log}'/preprocess.kneaddata-%A_%a.slurm.out
#SBATCH --time='${walltime}'
#SBATCH --mem='${mem}'
#SBATCH -N 1
#SBATCH -n '${threads}'
#SBATCH -A '${alloc}'
#SBATCH -J preprocess
' >> ${out}/preprocess.kneaddata.slurm.sh

if [ "$email" != "false" ]; then
echo '
#SBATCH --mail-user='${email}'
' >> ${out}/preprocess.kneaddata.slurm.sh
fi

echo '

newgrp def-ilafores
echo "loading env"
export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6
module use $MUGQIC_INSTALL_HOME/modulefiles
module load StdEnv/2020 gcc/9 python/3.7.9 java/14.0.2 mugqic/bowtie2/2.3.5 mugqic/trimmomatic/0.39 mugqic/TRF/4.09 mugqic/fastqc/0.11.5 mugqic/samtools/1.14 mugqic/BBMap/38.90
export PATH=/cvmfs/soft.mugqic/CentOS6/software/trimmomatic/Trimmomatic-0.39:$PATH

export __sample_line=$(cat '${sample_tsv}' | awk "NR==$SLURM_ARRAY_TASK_ID")
export __sample=$(echo -e "$__sample_line" | cut -f1)
export __fastq_file1=$(echo -e "$__sample_line" | cut -f2)
export __fastq_file2=$(echo -e "$__sample_line" | cut -f3)

bash '${EXE_PATH}'/scripts/preprocess.kneaddata.sh \
-o '${out}'/$__sample \
-tmp $SLURM_TMPDIR \
-t '${threads}' -m '${mem}' \
-s $__sample -fq1 $__fastq_file1 -fq2 $__fastq_file2 \
--trimmomatic_options "'${trimmomatic_adapters} ${trimmomatic_options}'" \
--bowtie2_options "'$bowtie2_options'" \
--db '$db'
' >> ${out}/preprocess.kneaddata.slurm.sh

echo "Generate preprocessed reads sample tsv: ${out}/preprocessed_reads.sample.tsv"
rm -f ${out}/taxonomic_profile.sample.tsv
while IFS=$'\t' read -r name f1 f2
do
    echo -e "${name}\t${out}/${name}/${name}_paired_1.fastq\t${out}/${name}/${name}_paired_2.fastq" >> ${out}/preprocessed_reads.sample.tsv
done < ${sample_tsv}

# echo "Generate functionnal profiling sample tsv: ${out}/functionnal_profile.sample.tsv"
# rm -f ${out}/functionnal_profile.sample.tsv
# while IFS=$'\t' read -r name f1 f2
# do
#     echo -e "${name}\t${out}/${name}/${name}_cat-paired.fastq" >> ${out}/functionnal_profile.sample.tsv
# done < ${sample_tsv}

echo "To submit to slurm, execute the following command:"
read sample_nbr f <<< $(wc -l ${sample_tsv})
echo "sbatch --array=1-$sample_nbr ${out}/preprocess.kneaddata.slurm.sh"

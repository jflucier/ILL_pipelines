#!/bin/bash

set -e

echo "load and valdiate env"
# load and valdiate env
export EXE_PATH=$(dirname "$0")

if [ -z ${1+x} ]; then
    echo "Please provide a configuration file. See ${EXE_PATH}/my.example.config for an example."
    exit 1
fi

export CONF_PARAMETERS=$1
export TMP_DIR=$2
export __line_nbr=$3

module load StdEnv/2020 gcc/9 python/3.7.9 java/14.0.2 mugqic/bowtie2/2.3.5 mugqic/trimmomatic/0.39 mugqic/TRF/4.09 mugqic/fastqc/0.11.5 mugqic/samtools/1.14
export PATH=/cvmfs/soft.mugqic/CentOS6/software/trimmomatic/Trimmomatic-0.39:$PATH

source $CONF_PARAMETERS

${EXE_PATH}/global.checkenv.sh
${EXE_PATH}/preprocess.checkenv.sh

mkdir -p ${OUPUT_PATH}/preprocess

export __sample_line=$(cat ${PREPROCESS_SAMPLES_LIST_TSV} | awk "NR==$__line_nbr")
export __sample=$(echo -e "$__sample_line" | cut -f1)
export __fastq1=$(echo -e "$__sample_line" | cut -f2)
export __fastq2=$(echo -e "$__sample_line" | cut -f3)
export __fastq_file1=$(basename $__fastq1)
export __fastq_file2=$(basename $__fastq2)

echo "copying fastq $__fastq1"
cp $__fastq1 $TMP_DIR/${__fastq_file1}
echo "copying fastq $__fastq2"
cp $__fastq2 $TMP_DIR/${__fastq_file2}

### Preproc
source /project/def-ilafores/common/kneaddata/bin/activate
mkdir -p $TMP_DIR/${__sample}

echo "running kneaddata. kneaddata ouptut: $TMP_DIR/${__sample}/"
###### pas de decontamine, output = $TMP_DIR/${__sample}/*repeats* --> peut changer etape pour fastp et cutadapt
kneaddata -v \
--log ${OUPUT_PATH}/preprocess/preprocess.kneaddata-${__sample}.log \
--input $TMP_DIR/${__fastq_file1} \
--input $TMP_DIR/${__fastq_file2} \
-db ${PREPROCESS_KNEADDATA_DB} \
--bowtie2-options="${PREPROCESS_KNEADDATA_BOWTIE2_OPTIONS}" \
-o $TMP_DIR/${__sample} \
--output-prefix ${__sample} \
--threads ${PREPROCESS_SLURM_NBR_THREADS} \
--max-memory ${PREPROCESS_SLURM_MEMORY} \
--sequencer-source="${PREPROCESS_KNEADDATA_SEQUENCER}" \
--trimmomatic-options="${PREPROCESS_KNEADDATA_TRIMMOMATIC}" \
--run-fastqc-start \
--run-fastqc-end

echo "deleting kneaddata uncessary files"
rm $TMP_DIR/${__sample}/*repeats* $TMP_DIR/${__sample}/*trimmed*

echo "moving contaminants fastqs to subdir"
mkdir -p $TMP_DIR/${__sample}/${__sample}_contaminants
mv $TMP_DIR/${__sample}/*contam*.fastq $TMP_DIR/${__sample}/${__sample}_contaminants/

echo "concatenate paired output, for HUMAnN single-end run"
cat $TMP_DIR/${__sample}/${__sample}_paired_1.fastq $TMP_DIR/${__sample}/${__sample}_paired_2.fastq > $TMP_DIR/${__sample}/${__sample}_cat-paired.fastq

echo "copying all kneaddata results to $OUPUT_PATH/preprocess/${__sample}"
cp -r $TMP_DIR/${__sample} $OUPUT_PATH/preprocess

echo "done ${__sample}"

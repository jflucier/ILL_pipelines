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

module load StdEnv/2020 gcc/9 python/3.7.9 java/14.0.2 mugqic/bowtie2/2.3.5 mugqic/trimmomatic/0.39 mugqic/TRF/4.09 mugqic/fastqc/0.11.5 mugqic/samtools/1.14 mugqic/BBMap/38.90
export PATH=/cvmfs/soft.mugqic/CentOS6/software/trimmomatic/Trimmomatic-0.39:$PATH

source $CONF_PARAMETERS

${EXE_PATH}/global.checkenv.sh
${EXE_PATH}/preprocess.checkenv.sh

mkdir -p ${OUTPUT_PATH}/${PREPROCESS_OUTPUT_NAME}

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
mkdir -p $TMP_DIR/${PREPROCESS_OUTPUT_NAME}/${__sample}

echo "running kneaddata. kneaddata ouptut: $TMP_DIR/${PREPROCESS_OUTPUT_NAME}/${__sample}/"
###### pas de decontamine, output = $TMP_DIR/${__sample}/*repeats* --> peut changer etape pour fastp et cutadapt
kneaddata -v \
--log ${OUTPUT_PATH}/${PREPROCESS_OUTPUT_NAME}/logs/preprocess.kneaddata-${__sample}.log \
--input $TMP_DIR/${__fastq_file1} \
--input $TMP_DIR/${__fastq_file2} \
-db ${PREPROCESS_KNEADDATA_DB} \
--bowtie2-options="${PREPROCESS_KNEADDATA_BOWTIE2_OPTIONS}" \
-o $TMP_DIR/${PREPROCESS_OUTPUT_NAME}/${__sample} \
--output-prefix ${__sample} \
--threads ${PREPROCESS_SLURM_NBR_THREADS} \
--max-memory ${PREPROCESS_SLURM_MEMORY} \
--sequencer-source="${PREPROCESS_KNEADDATA_SEQUENCER}" \
--trimmomatic-options="${PREPROCESS_KNEADDATA_TRIMMOMATIC}" \
--run-fastqc-start \
--run-fastqc-end

echo "deleting kneaddata uncessary files"
rm $TMP_DIR/${PREPROCESS_OUTPUT_NAME}/${__sample}/*repeats* $TMP_DIR/${PREPROCESS_OUTPUT_NAME}/${__sample}/*trimmed*

echo "moving contaminants fastqs to subdir"
mkdir -p $TMP_DIR/${PREPROCESS_OUTPUT_NAME}/${__sample}/${__sample}_contaminants
mv $TMP_DIR/${PREPROCESS_OUTPUT_NAME}/${__sample}/*contam*.fastq $TMP_DIR/${PREPROCESS_OUTPUT_NAME}/${__sample}/${__sample}_contaminants/

#/localscratch/jflucier.10170.0/${PREPROCESS_OUTPUT_NAME}/N-1-TORTOR-G/N-1-TORTOR-G_paired_1.fastq
# echo "sort & reorder paired fastq using bbmap prior to metawrap assembly"
# repair.sh \
# in=${TMP_DIR}/${PREPROCESS_OUTPUT_NAME}/${__sample}/${__sample}_paired_1.fastq \
# in2=${TMP_DIR}/${PREPROCESS_OUTPUT_NAME}/${__sample}/${__sample}_paired_2.fastq \
# out=${TMP_DIR}/${PREPROCESS_OUTPUT_NAME}/${__sample}/${__sample}_paired_sorted_1.fastq \
# out2=${TMP_DIR}/${PREPROCESS_OUTPUT_NAME}/${__sample}/${__sample}_paired_sorted_2.fastq


echo "concatenate paired output, for HUMAnN single-end run"
cat $TMP_DIR/${PREPROCESS_OUTPUT_NAME}/${__sample}/${__sample}_paired_1.fastq $TMP_DIR/${PREPROCESS_OUTPUT_NAME}/${__sample}/${__sample}_paired_2.fastq > $TMP_DIR/${PREPROCESS_OUTPUT_NAME}/${__sample}/${__sample}_cat-paired.fastq

echo "copying all kneaddata results to $OUTPUT_PATH/${PREPROCESS_OUTPUT_NAME}/${__sample}"
cp -fr $TMP_DIR/${PREPROCESS_OUTPUT_NAME}/${__sample} $OUTPUT_PATH/${PREPROCESS_OUTPUT_NAME}/

echo "done ${__sample}"

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

module load StdEnv/2020 gcc/9 python/3.7.9 java/14.0.2 singularity/3.7 mugqic/BBMap/38.90

# import env variables
source $CONF_PARAMETERS

${EXE_PATH}/global.checkenv.sh
#${EXE_PATH}/preprocess.checkenv.sh

# export __sample_line=$(cat ${ASSEMBLY_SAMPLE_LIST_TSV} | awk "NR==$__line_nbr")
# export __sample=$(echo -e "$__sample_line" | cut -f1)
export __bin_refinement_name=metawrap_${ASSEMBLY_BIN_REFINEMENT_MIN_COMPLETION}_${ASSEMBLY_BIN_REFINEMENT_MAX_CONTAMINATION}_bins
# export __fastq_file1=$(echo -e "$__sample_line" | cut -f2)
# export __fastq_file2=$(echo -e "$__sample_line" | cut -f3)

mkdir -p ${TMP_DIR}

echo "upload bins to ${TMP_DIR}/"
echo "bins folder: $__bin_refinement_name"
cp -r ${OUPUT_PATH}/bin_refinement/$__bin_refinement_name ${TMP_DIR}/${__sample}/
cp -r ${OUPUT_PATH}/assembly/final_assembly.fasta ${TMP_DIR}/${__sample}/
# cp -r ${OUPUT_PATH}/preprocess/${__sample}_paired_1.fastq ${TMP_DIR}/${__sample}/
# cp -r ${OUPUT_PATH}/preprocess/${__sample}_paired_2.fastq ${TMP_DIR}/${__sample}/

echo "running salmond"
mkdir -p ${TMP_DIR}/bin_quantification/
singularity exec --writable-tmpfs -e \
-B ${TMP_DIR}:/out \
-B ${OUPUT_PATH} \
-B /ssdpool/shared/ilafores_group/checkm_db:/checkm \
-B /ssdpool/shared/ilafores_group/NCBI_nt:/NCBI_nt \
-B /ssdpool/shared/ilafores_group/NCBI_tax:/NCBI_tax \
${EXE_PATH}/../containers/metawrap.1.3.sif \
metawrap quant_bins \
-t $QUANTIFY_SLURM_NBR_THREADS \
-b /out/${__bin_refinement_name} \
-o /out/bin_quantification \
-a /out/final_assembly.fasta $QUANTIFY_SAMPLE_PATH_REGEX

echo "running blobology"
mkdir -p ${TMP_DIR}/blobology/
singularity exec --writable-tmpfs -e \
-B ${TMP_DIR}:/out \
-B ${OUPUT_PATH} \
-B /ssdpool/shared/ilafores_group/checkm_db:/checkm \
-B /ssdpool/shared/ilafores_group/NCBI_nt:/NCBI_nt \
-B /ssdpool/shared/ilafores_group/NCBI_tax:/NCBI_tax \
${EXE_PATH}/../containers/metawrap.1.3.sif \
metawrap blobology \
-a /out/final_assembly.fasta \
-t $QUANTIFY_SLURM_NBR_THREADS \
-o /out/blobology \
--bins /out/${__bin_refinement_name} \
$QUANTIFY_SAMPLE_PATH_REGEX

echo "copying results back to $OUPUT_PATH/"
cp -r ${TMP_DIR}/bin_quantification $OUPUT_PATH/
cp -r ${TMP_DIR}/blobology $OUPUT_PATH/


echo "quantify bin pipeline done"

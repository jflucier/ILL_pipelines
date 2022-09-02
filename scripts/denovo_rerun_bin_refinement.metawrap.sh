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
${EXE_PATH}/denovo_assembly_bin_refinement.metawrap.checkenv.sh

export __sample_line=$(cat ${ASSEMBLY_SAMPLE_LIST_TSV} | awk "NR==$__line_nbr")
export __sample=$(echo -e "$__sample_line" | cut -f1)
export __fastq_file1=$(echo -e "$__sample_line" | cut -f2)
export __fastq_file2=$(echo -e "$__sample_line" | cut -f3)

echo "copying bins in temps dir"
cp -r $OUTPUT_PATH/${ASSEMBLY_OUTPUT_NAME}/binning/${__sample}/* ${TMP_DIR}/binning/

# echo "copying binning results back to $OUTPUT_PATH/binning/${__sample}/"
# mkdir -p $OUTPUT_PATH/${ASSEMBLY_OUTPUT_NAME}/binning/${__sample}/
# cp -r ${TMP_DIR}/binning/* $OUTPUT_PATH/${ASSEMBLY_OUTPUT_NAME}/binning/${__sample}/

# around 2.5 hr of exec
echo "metawrap bin refinement"
mkdir ${TMP_DIR}/bin_refinement/
singularity exec --writable-tmpfs -e \
-B ${TMP_DIR}:/out \
-B /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/checkm_db:/checkm \
-B /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/NCBI_nt:/NCBI_nt \
-B /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/NCBI_tax:/NCBI_tax \
${EXE_PATH}/../containers/metawrap.1.3.sif \
metawrap bin_refinement -t $ASSEMBLY_SLURM_NBR_THREADS -m $BINNING_MEM --quick \
-c $ASSEMBLY_BIN_REFINEMENT_MIN_COMPLETION -x $ASSEMBLY_BIN_REFINEMENT_MAX_CONTAMINATION \
-o /out/bin_refinement/ \
-A /out/binning/metabat2_bins/ \
-B /out/binning/maxbin2_bins/ \
-C /out/binning/concoct_bins/

echo "copying bin_refinement results back to $OUTPUT_PATH/bin_refinement/${__sample}/"
mkdir -p $OUTPUT_PATH/${ASSEMBLY_OUTPUT_NAME}/bin_refinement/${__sample}/
cp -r ${TMP_DIR}/bin_refinement/* $OUTPUT_PATH/${ASSEMBLY_OUTPUT_NAME}/bin_refinement/${__sample}/


echo "metawrap binning refinement pipeline done"

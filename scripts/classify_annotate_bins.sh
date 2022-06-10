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

echo "analysing sample $__sample with gtdbtk"

mkdir -p ${TMP_DIR}/

echo "upload bins to ${TMP_DIR}/"
echo "bins folder: $__bin_refinement_name"
cp -r ${OUPUT_PATH}/bin_refinement/$__bin_refinement_name ${TMP_DIR}/

# run gtdbtk
echo "running gtdbtk annotation pipeline on refined bins"
mkdir -p ${TMP_DIR}/bin_classification
mkdir -p ${TMP_DIR}/temp
singularity exec --writable-tmpfs -e \
-B ${TMP_DIR}:/out \
-B /ssdpool/shared/ilafores_group/GTDB/release207_v2:/GTDB \
${EXE_PATH}/../containers/metawrap.1.3.sif \
gtdbtk classify_wf \
-x fa \
--genome_dir /out/${__bin_refinement_name}/ \
--out_dir /out/bin_classification/ \
--cpus $ANNOTATE_SLURM_NBR_THREADS --pplacer_cpus $ANNOTATE_PPLACER_NBR_THREADS \
--scratch_dir /out/temp --tmpdir /out/temp

mkdir -p ${TMP_DIR}/prokka
for b in ${TMP_DIR}/${__bin_refinement_name}/*.fa
do
    fullname=$(basename $b)
    name=${fullname%.fa}
    echo "running prokka on bin $name"
    singularity exec --writable-tmpfs -e \
    -B ${TMP_DIR}:/out \
    ${EXE_PATH}/../containers/metawrap.1.3.sif \
    /miniconda3/envs/metawrap-env/bin/prokka --force --cpus $ANNOTATE_SLURM_NBR_THREADS \
    --outdir /out/prokka \
    --prefix $name /out/${__bin_refinement_name}/${fullname}
done

mkdir -p ${TMP_DIR}/roary
singularity exec --writable-tmpfs -e \
-B ${TMP_DIR}:/out \
${EXE_PATH}/../containers/metawrap.1.3.sif \
roary -e --mafft -p $ANNOTATE_SLURM_NBR_THREADS -f /out/roary /out/prokka/*.gff

# copy back results
echo "copying results back to $OUPUT_PATH"
cp -r ${TMP_DIR}/bin_classification $OUPUT_PATH/bin_classification
cp -r ${TMP_DIR}/bin_classification $OUPUT_PATH/prokka
cp -r ${TMP_DIR}/bin_classification $OUPUT_PATH/roary


echo "gtdbtk annotation pipeline done"

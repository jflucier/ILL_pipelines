#!/bin/bash

set -e

echo "load and validate env"
# load and valdiate env
export EXE_PATH=$(dirname "$0")

if [ -z ${1+x} ]; then
    echo "Please provide a configuration file. See ${EXE_PATH}/my.example.config for an example."
    exit 1
fi

echo "parameter file is $1"
export CONF_PARAMETERS=$1
source $CONF_PARAMETERS

${EXE_PATH}/scripts/global.checkenv.sh
${EXE_PATH}/scripts/preprocess.checkenv.sh

mkdir -p ${OUTPUT_PATH}/${PREPROCESS_OUTPUT_NAME}/logs

echo "outputting make custom buglist db slurm script to ${OUTPUT_PATH}/${PREPROCESS_OUTPUT_NAME}/preprocess.kneaddata.slurm.sh"
echo '#!/bin/bash' > ${OUTPUT_PATH}/${PREPROCESS_OUTPUT_NAME}/preprocess.kneaddata.slurm.sh
echo '

#SBATCH --mail-type=END,FAIL
#SBATCH -D '${OUTPUT_PATH}'
#SBATCH -o '${OUTPUT_PATH}'/'${PREPROCESS_OUTPUT_NAME}'/logs/preprocess.kneaddata-%A_%a.slurm.out
#SBATCH --time='${PREPROCESS_SLURM_WALLTIME}'
#SBATCH --mem='${PREPROCESS_SLURM_MEMORY}'
#SBATCH --mail-user='${SLURM_JOB_EMAIL}'
#SBATCH -N 1
#SBATCH -n '${PREPROCESS_SLURM_NBR_THREADS}'
#SBATCH -A '${SLURM_ALLOCATION}'
#SBATCH -J buglist

set -e

newgrp def-ilafores
echo "loading env"
export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6
module use $MUGQIC_INSTALL_HOME/modulefiles

bash '${EXE_PATH}'/scripts/preprocess.kneaddata.sh \
'$CONF_PARAMETERS' \
$SLURM_TMPDIR \
$SLURM_ARRAY_TASK_ID

' >> ${OUTPUT_PATH}/${PREPROCESS_OUTPUT_NAME}/preprocess.kneaddata.slurm.sh

echo "Generate taxonomic profiling sample tsv: ${OUTPUT_PATH}/${PREPROCESS_OUTPUT_NAME}/taxonomic_profile.sample.tsv"
rm -f ${OUTPUT_PATH}/${PREPROCESS_OUTPUT_NAME}/taxonomic_profile.sample.tsv
while IFS=$'\t' read -r name f1 f2
do
    echo -e "${name}\t${OUTPUT_PATH}/${PREPROCESS_OUTPUT_NAME}/${name}/${name}_paired_1.fastq\t${OUTPUT_PATH}/${PREPROCESS_OUTPUT_NAME}/${name}/${name}_paired_2.fastq" >> ${OUTPUT_PATH}/${PREPROCESS_OUTPUT_NAME}/taxonomic_profile.sample.tsv
done < ${PREPROCESS_SAMPLES_LIST_TSV}

echo "Generate functionnal profiling sample tsv: ${OUTPUT_PATH}/${PREPROCESS_OUTPUT_NAME}/functionnal_profile.sample.tsv"
rm -f ${OUTPUT_PATH}/${PREPROCESS_OUTPUT_NAME}/functionnal_profile.sample.tsv
while IFS=$'\t' read -r name f1 f2
do
    echo -e "${name}\t${OUTPUT_PATH}/${PREPROCESS_OUTPUT_NAME}/${name}/${name}_cat-paired.fastq" >> ${OUTPUT_PATH}/${PREPROCESS_OUTPUT_NAME}/functionnal_profile.sample.tsv
done < ${PREPROCESS_SAMPLES_LIST_TSV}

echo "To submit to slurm, execute the following command:"
read sample_nbr f <<< $(wc -l ${PREPROCESS_SAMPLES_LIST_TSV})
echo "sbatch --array=1-$sample_nbr ${OUTPUT_PATH}/${PREPROCESS_OUTPUT_NAME}/preprocess.kneaddata.slurm.sh"

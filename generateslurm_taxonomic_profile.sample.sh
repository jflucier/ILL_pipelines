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
source $CONF_PARAMETERS

${EXE_PATH}/scripts/global.checkenv.sh
${EXE_PATH}/scripts/taxonomic_profile.sample.checkenv.sh

mkdir -p ${OUTPUT_PATH}/${TAXONOMIC_SAMPLE_OUTPUT_NAME}/logs

echo "outputting make custom buglist db slurm script to ${OUTPUT_PATH}/${TAXONOMIC_SAMPLE_OUTPUT_NAME}/taxonomic_profile.slurm.sh"
echo '#!/bin/bash' > ${OUTPUT_PATH}/${TAXONOMIC_SAMPLE_OUTPUT_NAME}/taxonomic_profile.slurm.sh
echo '
#SBATCH --mail-type=END,FAIL
#SBATCH -D '${OUTPUT_PATH}'
#SBATCH -o '${OUTPUT_PATH}'/'${TAXONOMIC_SAMPLE_OUTPUT_NAME}'/logs/taxonomic_profile-%A_%a.slurm.out
#SBATCH --time='${TAXONOMIC_SAMPLE_SLURM_WALLTIME}'
#SBATCH --mem='${TAXONOMIC_SAMPLE_SLURM_MEMORY}'
#SBATCH --mail-user='${SLURM_JOB_EMAIL}'
#SBATCH -N 1
#SBATCH -n '${TAXONOMIC_SAMPLE_SLURM_NBR_THREADS}'
#SBATCH -A '${SLURM_ALLOCATION}'
#SBATCH -J taxonomic_profile

newgrp def-ilafores
echo "loading env"
export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6
module use $MUGQIC_INSTALL_HOME/modulefiles

bash '${EXE_PATH}'/scripts/taxonomic_profile.sample.sh \
'$CONF_PARAMETERS' \
$SLURM_TMPDIR \
$SLURM_ARRAY_TASK_ID

' >> ${OUTPUT_PATH}/${TAXONOMIC_SAMPLE_OUTPUT_NAME}/taxonomic_profile.slurm.sh

echo "To submit to slurm, execute the following command:"
read sample_nbr f <<< $(wc -l ${TAXONOMIC_SAMPLE_SAMPLES_LIST_TSV})
echo "sbatch --array=1-$sample_nbr ${OUTPUT_PATH}/${TAXONOMIC_SAMPLE_OUTPUT_NAME}/taxonomic_profile.slurm.sh"

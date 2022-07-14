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
${EXE_PATH}/scripts/taxonomic_profile.allsamples.checkenv.sh

mkdir -p ${OUTPUT_PATH}/${TAXONOMIC_ALL_OUTPUT_NAME}/logs

echo "outputting all sample taxonomic profile slurm script to ${OUTPUT_PATH}/${TAXONOMIC_ALL_OUTPUT_NAME}/taxonomic_profile.allsamples.slurm.sh"
echo '#!/bin/bash' > ${OUTPUT_PATH}/${TAXONOMIC_ALL_OUTPUT_NAME}/taxonomic_profile.allsamples.slurm.sh
echo '
#SBATCH --mail-type=END,FAIL
#SBATCH -D '${OUTPUT_PATH}'
#SBATCH -o '${OUTPUT_PATH}'/'${TAXONOMIC_ALL_OUTPUT_NAME}'/logs/taxonomic_profile_all-%A.slurm.out
#SBATCH --time='${TAXONOMIC_ALL_SLURM_WALLTIME}'
#SBATCH --mem='${TAXONOMIC_ALL_SLURM_MEMORY}'
#SBATCH --mail-user='${SLURM_JOB_EMAIL}'
#SBATCH -N 1
#SBATCH -n '${TAXONOMIC_ALL_SLURM_NBR_THREADS}'
#SBATCH -A '${SLURM_ALLOCATION}'
#SBATCH -J all_taxonomic_profile


newgrp def-ilafores
echo "loading env"
export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6
module use $MUGQIC_INSTALL_HOME/modulefiles

bash '${EXE_PATH}'/scripts/taxonomic_profile.allsamples.sh \
'$CONF_PARAMETERS' \
$SLURM_TMPDIR

' >> ${OUTPUT_PATH}/${TAXONOMIC_ALL_OUTPUT_NAME}/taxonomic_profile.allsamples.slurm.sh

echo "To submit to slurm, execute the following command:"
echo "sbatch ${OUTPUT_PATH}/${TAXONOMIC_ALL_OUTPUT_NAME}/taxonomic_profile.allsamples.slurm.sh"

echo "done!"

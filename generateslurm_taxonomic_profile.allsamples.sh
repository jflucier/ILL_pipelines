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

mkdir -p ${OUPUT_PATH}/taxonomic_profile_all

echo "outputting all sample taxonomic profile slurm script to ${OUPUT_PATH}/taxonomic_profile_all/taxonomic_profile.allsamples.slurm.sh"
echo '#!/bin/bash' > ${OUPUT_PATH}/taxonomic_profile_all/taxonomic_profile.allsamples.slurm.sh
echo '
#SBATCH --mail-type=END,FAIL
#SBATCH -D '${OUPUT_PATH}'
#SBATCH -o '${OUPUT_PATH}'/taxonomic_profile_all/taxonomic_profile_all-%A.slurm.out
#SBATCH --time='${TAXONOMIC_ALL_SLURM_WALLTIME}'
#SBATCH --mem='${TAXONOMIC_ALL_SLURM_MEMORY}'
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

' >> ${OUPUT_PATH}/taxonomic_profile_all/taxonomic_profile.allsamples.slurm.sh

echo "To submit to slurm, execute the following command:"
echo "sbatch ${OUPUT_PATH}/taxonomic_profile_all/taxonomic_profile.allsamples.slurm.sh"

echo "done!"

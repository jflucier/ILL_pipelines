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
${EXE_PATH}/scripts/functionnal_profile.humann.checkenv.sh

mkdir -p ${OUPUT_PATH}/functionnal_profile/$FUNCPROFILING_SEARCH_MODE

echo "outputting humann custom slurm script to ${OUPUT_PATH}/functionnal_profile/functionnal_profile.slurm.sh"

echo '#!/bin/bash' > ${OUPUT_PATH}/functionnal_profile/functionnal_profile.slurm.sh
echo '
#SBATCH --mail-type=END,FAIL
#SBATCH -D '${OUPUT_PATH}'
#SBATCH -o '${OUPUT_PATH}'/functionnal_profile/'$FUNCPROFILING_SEARCH_MODE'/functionnal_profile-%A_%a.slurm.out' >> ${OUPUT_PATH}/functionnal_profile/functionnal_profile.slurm.sh
#SBATCH --mail-user='${SLURM_JOB_EMAIL}'

case $FUNCPROFILING_SEARCH_MODE in

  "DUAL" | "NT" )
    echo '#SBATCH --time='${FUNCPROFILING_SLURM_FAT_WALLTIME} >> ${OUPUT_PATH}/functionnal_profile/functionnal_profile.slurm.sh
    echo '#SBATCH --mem='${FUNCPROFILING_SLURM_FAT_MEMORY} >> ${OUPUT_PATH}/functionnal_profile/functionnal_profile.slurm.sh
    echo '#SBATCH -n '${FUNCPROFILING_SLURM_FAT_NBR_THREADS} >> ${OUPUT_PATH}/functionnal_profile/functionnal_profile.slurm.sh
    ;;

  "PROT" )
    echo '#SBATCH --time='${FUNCPROFILING_SLURM_BASE_WALLTIME} >> ${OUPUT_PATH}/functionnal_profile/functionnal_profile.slurm.sh
    echo '#SBATCH --mem='${FUNCPROFILING_SLURM_BASE_MEMORY} >> ${OUPUT_PATH}/functionnal_profile/functionnal_profile.slurm.sh
    echo '#SBATCH -n '${FUNCPROFILING_SLURM_BASE_NBR_THREADS} >> ${OUPUT_PATH}/functionnal_profile/functionnal_profile.slurm.sh
    ;;

  *)
    echo "Unrecongnised FUNCPROFILING_SEARCH_MODE: $FUNCPROFILING_SEARCH_MODE"
    echo "Possible modes are: DUAL, NT or PROT "
    echo "Please edit configuration at this line: export FUNCPROFILING_SEARCH_MODE=\"DUAL\""
    exit 1
    ;;
esac

echo '#SBATCH -N 1
#SBATCH -A '${SLURM_ALLOCATION}'
#SBATCH -J functionnal_profile

newgrp def-ilafores
echo "loading env"
export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6
module use $MUGQIC_INSTALL_HOME/modulefiles

bash '${EXE_PATH}'/scripts/functionnal_profile.humann.sh \
'$CONF_PARAMETERS' \
$SLURM_TMPDIR \
$SLURM_ARRAY_TASK_ID

' >> ${OUPUT_PATH}/functionnal_profile/functionnal_profile.slurm.sh

echo "To submit to slurm, execute the following command:"
read sample_nbr f <<< $(wc -l ${FUNCPROFILING_SAMPLES_LIST_TSV})
echo "sbatch --array=1-$sample_nbr ${OUPUT_PATH}/functionnal_profile/functionnal_profile.slurm.sh"

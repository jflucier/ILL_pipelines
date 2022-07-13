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
${EXE_PATH}/scripts/denovo_assembly.metawrap.checkenv.sh

mkdir -p ${OUPUT_PATH}/denovo_assembly

echo "outputting denovo assembly slurm script to ${OUPUT_PATH}/denovo_assembly/denovo_assembly.metawrap.slurm.sh"

echo '#!/bin/bash' > ${OUPUT_PATH}/denovo_assembly/denovo_assembly.metawrap.slurm.sh
echo '
#SBATCH --mail-type=END,FAIL
#SBATCH -D '${OUPUT_PATH}'
#SBATCH -o '${OUPUT_PATH}'/denovo_assembly/denovo_assembly-%A_%a.slurm.out
#SBATCH --time='${ASSEMBLY_SLURM_WALLTIME}'
#SBATCH --mem='${ASSEMBLY_SLURM_MEMORY}'
#SBATCH --mail-user='${SLURM_JOB_EMAIL}'
#SBATCH -N 1
#SBATCH -n '${ASSEMBLY_SLURM_NBR_THREADS}'
#SBATCH -A '${SLURM_ALLOCATION}'
#SBATCH -J denovo_assembly

newgrp def-ilafores
echo "loading env"
export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6
module use $MUGQIC_INSTALL_HOME/modulefiles

bash '${EXE_PATH}'/scripts/denovo_assembly.metawrap.sh \
'$CONF_PARAMETERS' \
$SLURM_TMPDIR \
$SLURM_ARRAY_TASK_ID

' >> ${OUPUT_PATH}/denovo_assembly/denovo_assembly.metawrap.slurm.sh

echo "To submit to slurm, execute the following command:"
read sample_nbr f <<< $(wc -l ${ASSEMBLY_SAMPLE_LIST_TSV})
echo "sbatch --array=1-$sample_nbr ${OUPUT_PATH}/denovo_assembly/denovo_assembly.metawrap.slurm.sh"

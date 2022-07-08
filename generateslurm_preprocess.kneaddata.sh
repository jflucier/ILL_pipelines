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

mkdir -p ${OUPUT_PATH}/preprocess

echo "outputting make custom buglist db slurm script to ${OUPUT_PATH}/preprocess/preprocess.kneaddata.slurm.sh"
echo '#!/bin/bash' > ${OUPUT_PATH}/preprocess/preprocess.kneaddata.slurm.sh
echo '

#SBATCH --mail-type=END,FAIL
#SBATCH -D '${OUPUT_PATH}'/preprocess
#SBATCH -o '${OUPUT_PATH}'/preprocess/preprocess.kneaddata-%A_%a.slurm.out
#SBATCH --time='${PREPROCESS_SLURM_WALLTIME}'
#SBATCH --mem='${PREPROCESS_SLURM_MEMORY}'
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

' >> ${OUPUT_PATH}/preprocess/preprocess.kneaddata.slurm.sh

echo "Generate taxonomic profiling sample tsv: ${OUPUT_PATH}/preprocess/taxonomic_profile.sample.tsv"
rm -f ${OUPUT_PATH}/preprocess/taxonomic_profile.sample.tsv
while IFS=$'\t' read -r name f1 f2
do
    echo -e "${name}\t${OUPUT_PATH}/preprocess/${name}/${name}_paired_1.fastq\t${OUPUT_PATH}/preprocess/${name}/${name}_paired_2.fastq" >> ${OUPUT_PATH}/preprocess/taxonomic_profile.sample.tsv
done < ${PREPROCESS_SAMPLES_LIST_TSV}

echo "Generate functionnal profiling sample tsv: ${OUPUT_PATH}/preprocess/functionnal_profile.sample.tsv"
rm -f ${OUPUT_PATH}/preprocess/functionnal_profile.sample.tsv
while IFS=$'\t' read -r name f1 f2
do
    echo -e "${name}\t${OUPUT_PATH}/preprocess/${name}/${name}_cat-paired.fastq" >> ${OUPUT_PATH}/preprocess/functionnal_profile.sample.tsv
done < ${PREPROCESS_SAMPLES_LIST_TSV}

echo "Generate denovo assembly sample tsv: ${OUPUT_PATH}/preprocess/denovo_assembly.sample.tsv"
rm -f ${OUPUT_PATH}/preprocess/denovo_assembly.sample.tsv
while IFS=$'\t' read -r name f1 f2
do
    echo -e "${name}\t${OUPUT_PATH}/preprocess/${name}/${name}_paired_sorted_1.fastq\t${OUPUT_PATH}/preprocess/${name}/${name}_paired_sorted_2.fastq" >> ${OUPUT_PATH}/preprocess/denovo_assembly.sample.tsv
done < ${PREPROCESS_SAMPLES_LIST_TSV}


echo "To submit to slurm, execute the following command:"
read sample_nbr f <<< $(wc -l ${PREPROCESS_SAMPLES_LIST_TSV})
echo "sbatch --array=1-$sample_nbr ${OUPUT_PATH}/preprocess/preprocess.kneaddata.slurm.sh"

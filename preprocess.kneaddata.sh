#!/bin/bash

set -e

echo "load and valdiate env"
# load and valdiate env
export EXE_PATH=$(dirname "$0")

if [ -z ${1+x} ]; then
    echo "Please provide a configuration file. See ${EXE_PATH}/my.example.config for an example."
    exit 1
fi

source $1

${EXE_PATH}/global.checkenv.sh
${EXE_PATH}/preprocess.checkenv.sh

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

newgrp def-ilafores
echo "loading env"
export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6
module use $MUGQIC_INSTALL_HOME/modulefiles

export __sample_line=$(cat '${PREPROCESS_SAMPLES_LIST_TSV}' | awk "NR==$SLURM_ARRAY_TASK_ID")
export __sample=$(echo -e "$__sample_line" | cut -d$'"'"'\t'"'"' -f1)
export __fastq1=$(echo -e "$__sample_line" | cut -d$'"'"'\t'"'"' -f2)
export __fastq2=$(echo -e "$__sample_line" | cut -d$'"'"'\t'"'"' -f3)
export __fastq_file1=$(basename $__fastq1)
export __fastq_file2=$(basename $__fastq2)

echo "copying fastq $__fastq1"
cp $__fastq1 $SLURM_TMPDIR/${__fastq_file1}
echo "copying fastq $__fastq2"
cp $__fastq2 $SLURM_TMPDIR/${__fastq_file2}

module load StdEnv/2020 gcc/9 python/3.7.9 java/14.0.2 mugqic/bowtie2/2.3.5 mugqic/trimmomatic/0.39 mugqic/TRF/4.09 mugqic/fastqc/0.11.5 mugqic/samtools/1.14
export PATH=/cvmfs/soft.mugqic/CentOS6/software/trimmomatic/Trimmomatic-0.39:$PATH

### Preproc
source /project/def-ilafores/common/kneaddata/bin/activate
mkdir -p $SLURM_TMPDIR/${__sample}

echo "running kneaddata. kneaddata ouptut: $SLURM_TMPDIR/${__sample}/"
###### pas de decontamine, output = $SLURM_TMPDIR/${__sample}/*repeats* --> peut changer etape pour fastp et cutadapt
kneaddata -v \
--log '${OUPUT_PATH}'/preprocess/preprocess.kneaddata-${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.out \
--input $SLURM_TMPDIR/${__fastq_file1} \
--input $SLURM_TMPDIR/${__fastq_file2} \
-db '${PREPROCESS_KNEADDATA_DB}' \
--bowtie2-options="'${PREPROCESS_KNEADDATA_BOWTIE2_OPTIONS}'" \
-o $SLURM_TMPDIR/${__sample} \
--output-prefix ${__sample} \
--threads '${PREPROCESS_SLURM_NBR_THREADS}' \
--max-memory '${PREPROCESS_SLURM_MEMORY}' \
--sequencer-source="'${PREPROCESS_KNEADDATA_SEQUENCER}'" \
--trimmomatic-options="'${PREPROCESS_KNEADDATA_TRIMMOMATIC}'" \
--run-fastqc-start \
--run-fastqc-end

echo "deleting kneaddata uncessary files"
rm $SLURM_TMPDIR/${__sample}/*repeats* $SLURM_TMPDIR/${__sample}/*trimmed*

echo "moving contaminants fastqs to subdir"
mkdir -p $SLURM_TMPDIR/${__sample}/${__sample}_contaminants
mv $SLURM_TMPDIR/${__sample}/*contam*.fastq $SLURM_TMPDIR/${__sample}/${__sample}_contaminants/

echo "concatenate paired output, for HUMAnN single-end run"
cat $SLURM_TMPDIR/${__sample}/${__sample}_paired_1.fastq $SLURM_TMPDIR/${__sample}/${__sample}_paired_2.fastq > $SLURM_TMPDIR/${__sample}/${__sample}_cat-paired.fastq

echo "echo copying all kneaddata results to '$OUPUT_PATH'/preprocess/${__sample}"
cp -r $SLURM_TMPDIR/${__sample} '$OUPUT_PATH'/preprocess

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

echo "To submit to slurm, execute the following command:"
read sample_nbr f <<< $(wc -l ${PREPROCESS_SAMPLES_LIST_TSV})
echo "sbatch --array=1-$sample_nbr ${OUPUT_PATH}/preprocess/preprocess.kneaddata.slurm.sh"

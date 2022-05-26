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
${EXE_PATH}/taxonomic_profile.sample.checkenv.sh

mkdir -p ${OUPUT_PATH}/taxonomic_profile

echo "outputting make custom buglist db slurm script to ${OUPUT_PATH}/taxonomic_profile/taxonomic_profile.slurm.sh"
__all_taxas=$(echo "${TAXONOMIC_SAMPLE_LEVEL[@]}")
echo '#!/bin/bash' > ${OUPUT_PATH}/taxonomic_profile/taxonomic_profile.slurm.sh
echo '
#SBATCH --mail-type=END,FAIL
#SBATCH -D '${OUPUT_PATH}'
#SBATCH -o '${OUPUT_PATH}'/taxonomic_profile/taxonomic_profile-%A_%a.slurm.out
#SBATCH --time='${TAXONOMIC_SAMPLE_SLURM_WALLTIME}'
#SBATCH --mem='${TAXONOMIC_SAMPLE_SLURM_MEMORY}'
#SBATCH -N 1
#SBATCH -n '${TAXONOMIC_SAMPLE_SLURM_NBR_THREADS}'
#SBATCH -A '${SLURM_ALLOCATION}'
#SBATCH -J taxonomic_profile

newgrp def-ilafores
echo "loading env"
export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6
module use $MUGQIC_INSTALL_HOME/modulefiles

export __sample_line=$(cat '${TAXONOMIC_SAMPLE_SAMPLES_LIST_TSV}' | awk "NR==$SLURM_ARRAY_TASK_ID")
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

### Kraken
echo "loading kraken env"
source /project/def-ilafores/common/kraken2/venv/bin/activate
export PATH=/project/def-ilafores/common/kraken2:/project/def-ilafores/common/Bracken:$PATH
export PATH=/project/def-ilafores/common/KronaTools-2.8.1/bin:$PATH

mkdir -p $SLURM_TMPDIR/${__sample}/

echo "running kraken. Kraken ouptut: $SLURM_TMPDIR/${__sample}/"
kraken2 \
--memory-mapping \
--paired \
--threads '${TAXONOMIC_SAMPLE_SLURM_NBR_THREADS}' \
--db '${TAXONOMIC_SAMPLE_KRAKEN2_DB_PATH}' \
--use-names \
--output $SLURM_TMPDIR/${__sample}/${__sample}_taxonomy_nt \
--classified-out $SLURM_TMPDIR/${__sample}/${__sample}_classified_reads_#.fastq \
--unclassified-out $SLURM_TMPDIR/${__sample}/${__sample}_unclassified_reads_#.fastq \
--report $SLURM_TMPDIR/${__sample}/${__sample}.kreport \
$SLURM_TMPDIR/${__fastq_file1} $SLURM_TMPDIR/${__fastq_file2}

### Bracken reestimations
mkdir -p $SLURM_TMPDIR/${__sample}/${__sample}_bracken
echo "running bracken. Bracken Output: $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_S.bracken"

mkdir $SLURM_TMPDIR/${__sample}/${__sample}_kronagrams

for taxa_str in '$__all_taxas'
do
    taxa_oneletter=${taxa_str%%:*}
    taxa_name=${taxa_str#*:}
    echo "running bracken on $taxa. Bracken Output: $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_${taxa_oneletter}.bracken"
    bracken \
    -d '${TAXONOMIC_SAMPLE_KRAKEN2_DB_PATH}' \
    -i $SLURM_TMPDIR/${__sample}/${__sample}.kreport \
    -o $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_${taxa_oneletter}.bracken \
    -w $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_bracken_${taxa_oneletter}.kreport \
    -r '$TAXONOMIC_SAMPLE_BRACKEN_READ_LEN' \
    -l $taxa_oneletter

    echo "creating mpa formatted file for ${taxa_oneletter}"
    python /project/def-ilafores/common/KrakenTools/kreport2mpa.py \
    -r $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_bracken_${taxa_oneletter}.kreport \
    -o $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_bracken_${taxa_oneletter}.MPA.TXT \
    --display-header

    echo "creating kronagrams for ${taxa_oneletter}"
    python /project/def-ilafores/common/KrakenTools/kreport2krona.py \
    -r $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_bracken_${taxa_oneletter}.kreport \
    -o $SLURM_TMPDIR/${__sample}/${__sample}_kronagrams/${__sample}_${taxa_oneletter}.krona

    echo "generate html from kronagram for ${taxa_oneletter}"
    ktImportText \
		$SLURM_TMPDIR/${__sample}/${__sample}_kronagrams/${__sample}_${taxa_oneletter}.krona \
		-o $SLURM_TMPDIR/${__sample}/${__sample}_kronagrams/${__sample}_${taxa_oneletter}.html

done

python /project/def-ilafores/common/KrakenTools/kreport2mpa.py \
-r $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_bracken_S.kreport \
-o $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_temp.MPA.TXT

top_bugs=`wc -l $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_temp.MPA.TXT | awk '"'"'{print $1}'"'"'`

grep "|s" $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_temp.MPA.TXT \
| sort -k 2 -r -n - \
| head -n $((top_bugs / 50)) - `#selects top 2 percent bugs` \
| awk '"'"'{printf("%s\t\n", $0)}'"'"' - \
| awk '"'"'BEGIN{printf("#mpa_v30_CHOCOPhlAn_201901\n")}1'"'"' - \
> $SLURM_TMPDIR/${__sample}/${__sample}-bugs_list.MPA.TXT

echo "echo cpopying all results to '$OUPUT_PATH'/${__sample}"
cp -r $SLURM_TMPDIR/${__sample} '$OUPUT_PATH'/taxonomic_profile/

' >> ${OUPUT_PATH}/taxonomic_profile/taxonomic_profile.slurm.sh

echo "To submit to slurm, execute the following command:"
read sample_nbr f <<< $(wc -l ${TAXONOMIC_SAMPLE_SAMPLES_LIST_TSV})
echo "sbatch --array=1-$sample_nbr ${OUPUT_PATH}/taxonomic_profile/taxonomic_profile.slurm.sh"

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

module load StdEnv/2020 gcc/9 python/3.7.9 java/14.0.2 mugqic/bowtie2/2.3.5 mugqic/trimmomatic/0.39 mugqic/TRF/4.09 mugqic/fastqc/0.11.5 mugqic/samtools/1.14
export PATH=/cvmfs/soft.mugqic/CentOS6/software/trimmomatic/Trimmomatic-0.39:$PATH

source $CONF_PARAMETERS

${EXE_PATH}/global.checkenv.sh
${EXE_PATH}/taxonomic_profile.sample.checkenv.sh

mkdir -p ${OUPUT_PATH}/taxonomic_profile

export __sample_line=$(cat ${TAXONOMIC_SAMPLE_SAMPLES_LIST_TSV} | awk "NR==$__line_nbr")
export __sample=$(echo -e "$__sample_line" | cut -f1)
export __fastq1=$(echo -e "$__sample_line" | cut -f2)
export __fastq2=$(echo -e "$__sample_line" | cut -f3)
export __fastq_file1=$(basename $__fastq1)
export __fastq_file2=$(basename $__fastq2)

echo "copying fastq $__fastq1"
cp $__fastq1 $TMP_DIR/${__fastq_file1}
echo "copying fastq $__fastq2"
cp $__fastq2 $TMP_DIR/${__fastq_file2}


### Kraken
echo "loading kraken env"
source /project/def-ilafores/common/kraken2/venv/bin/activate
export PATH=/project/def-ilafores/common/kraken2:/project/def-ilafores/common/Bracken:$PATH
export PATH=/project/def-ilafores/common/KronaTools-2.8.1/bin:$PATH

mkdir -p $TMP_DIR/${__sample}/

echo "running kraken. Kraken ouptut: $TMP_DIR/${__sample}/"
kraken2 \
--memory-mapping \
--paired \
--threads ${TAXONOMIC_SAMPLE_SLURM_NBR_THREADS} \
--db ${TAXONOMIC_SAMPLE_KRAKEN2_DB_PATH} \
--use-names \
--output $TMP_DIR/${__sample}/${__sample}_taxonomy_nt \
--classified-out $TMP_DIR/${__sample}/${__sample}_classified_reads_#.fastq \
--unclassified-out $TMP_DIR/${__sample}/${__sample}_unclassified_reads_#.fastq \
--report $TMP_DIR/${__sample}/${__sample}.kreport \
$TMP_DIR/${__fastq_file1} $TMP_DIR/${__fastq_file2}

### Bracken reestimations
mkdir -p $TMP_DIR/${__sample}/${__sample}_bracken
echo "running bracken. Bracken Output: $TMP_DIR/${__sample}/${__sample}_bracken/${__sample}_S.bracken"

mkdir $TMP_DIR/${__sample}/${__sample}_kronagrams

__all_taxas=$(echo "${TAXONOMIC_SAMPLE_LEVEL[@]}")
for taxa_str in $__all_taxas
do
    taxa_oneletter=${taxa_str%%:*}
    taxa_name=${taxa_str#*:}
    echo "running bracken on $taxa. Bracken Output: $TMP_DIR/${__sample}/${__sample}_bracken/${__sample}_${taxa_oneletter}.bracken"
    bracken \
    -d ${TAXONOMIC_SAMPLE_KRAKEN2_DB_PATH} \
    -i $TMP_DIR/${__sample}/${__sample}.kreport \
    -o $TMP_DIR/${__sample}/${__sample}_bracken/${__sample}_${taxa_oneletter}.bracken \
    -w $TMP_DIR/${__sample}/${__sample}_bracken/${__sample}_bracken_${taxa_oneletter}.kreport \
    -r $TAXONOMIC_SAMPLE_BRACKEN_READ_LEN \
    -l $taxa_oneletter

    echo "creating mpa formatted file for ${taxa_oneletter}"
    python /project/def-ilafores/common/KrakenTools/kreport2mpa.py \
    -r $TMP_DIR/${__sample}/${__sample}_bracken/${__sample}_bracken_${taxa_oneletter}.kreport \
    -o $TMP_DIR/${__sample}/${__sample}_bracken/${__sample}_bracken_${taxa_oneletter}.MPA.TXT \
    --display-header

    echo "creating kronagrams for ${taxa_oneletter}"
    python /project/def-ilafores/common/KrakenTools/kreport2krona.py \
    -r $TMP_DIR/${__sample}/${__sample}_bracken/${__sample}_bracken_${taxa_oneletter}.kreport \
    -o $TMP_DIR/${__sample}/${__sample}_kronagrams/${__sample}_${taxa_oneletter}.krona

    echo "generate html from kronagram for ${taxa_oneletter}"
    ktImportText \
		$TMP_DIR/${__sample}/${__sample}_kronagrams/${__sample}_${taxa_oneletter}.krona \
		-o $TMP_DIR/${__sample}/${__sample}_kronagrams/${__sample}_${taxa_oneletter}.html

done

python /project/def-ilafores/common/KrakenTools/kreport2mpa.py \
-r $TMP_DIR/${__sample}/${__sample}_bracken/${__sample}_bracken_S.kreport \
-o $TMP_DIR/${__sample}/${__sample}_bracken/${__sample}_temp.MPA.TXT

top_bugs=`wc -l $TMP_DIR/${__sample}/${__sample}_bracken/${__sample}_temp.MPA.TXT | awk '{print $1}'`

grep "|s" $TMP_DIR/${__sample}/${__sample}_bracken/${__sample}_temp.MPA.TXT \
| sort -k 2 -r -n - \
| head -n $((top_bugs / 50)) - `#selects top 2 percent bugs` \
| awk '{printf("%s\t\n", $0)}' - \
| awk 'BEGIN{printf("#mpa_v30_CHOCOPhlAn_201901\n")}1' - \
> $TMP_DIR/${__sample}/${__sample}-bugs_list.MPA.TXT

echo "copying all results to $OUPUT_PATH/${__sample}"
cp -r $TMP_DIR/${__sample} $OUPUT_PATH/taxonomic_profile/

echo "done ${__sample}"

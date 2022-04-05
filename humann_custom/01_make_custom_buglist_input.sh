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
${EXE_PATH}/00_check_global_environment.sh
${EXE_PATH}/00_check_make_custom_buglist_environment.sh

echo "outputting make custom buglist db slurm script to ${OUPUT_PATH}/make_custom_buglist.slurm.sh"

echo '#!/bin/bash' > ${OUPUT_PATH}/make_custom_buglist.slurm.sh
echo '
#SBATCH --mail-type=END,FAIL
#SBATCH -D '${OUPUT_PATH}'
#SBATCH -o '${OUPUT_PATH}'/make_custom_buglist-%A_%a.slurm.out
#SBATCH --time='${SLURM_WALLTIME}'
#SBATCH --mem='${SLURM_MEMORY}'
#SBATCH -N 1
#SBATCH -n '${SLURM_NBR_THREADS}'
#SBATCH -A '${SLURM_ALLOCATION}'
#SBATCH -J humann

newgrp def-ilafores
echo "loading env"
export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6
module use $MUGQIC_INSTALL_HOME/modulefiles

module load StdEnv/2020 gcc/9 python/3.7.9 java/14.0.2 mugqic/bowtie2/2.3.5 mugqic/samtools/1.14 mugqic/usearch/10.0.240
export PATH=/nfs3_ib/ip29-ib/ip29/ilafores_group/programs/diamond-2.0.14/bin:$PATH

export __sample_line=$(cat '${SAMPLE_TSV}' | awk "NR==$SLURM_ARRAY_TASK_ID")
export __sample=$(echo -e "$__sample_line" | cut -d$'"'"'\t'"'"' -f1)
export __fastq1=$(echo -e "$__sample_line" | cut -d$'"'"'\t'"'"' -f2)
export __fastq2=$(echo -e "$__sample_line" | cut -d$'"'"'\t'"'"' -f3)
export __fastq_file1=$(basename $__fastq1)
export __fastq_file2=$(basename $__fastq2)

echo "copying fastq $__fastq1"
cp $__fastq1 $SLURM_TMPDIR/${__fastq_file1}
echo "copying fastq $__fastq2"
cp $__fastq2 $SLURM_TMPDIR/${__fastq_file2}

### Preproc
source /project/def-ilafores/common/kneaddata/bin/activate
mkdir -p $SLURM_TMPDIR/${__sample}

echo "running kneaddata. kneaddata ouptut: $SLURM_TMPDIR/${__sample}/"
kneaddata -v \
--input $SLURM_TMPDIR/${__fastq_file1} \
--input $SLURM_TMPDIR/${__fastq_file2} \
-db '$KNEADDATA_DB' \
--bowtie2-options="'${BOWTIE2_OPTIONS}'" \
-o $SLURM_TMPDIR/${__sample} \
--output-prefix ${__sample} \
--threads '${SLURM_NBR_THREADS}' \
--max-memory '${SLURM_MEMORY}' \
--sequencer-source="'${SEQUENCER}'" \
--trimmomatic-options="'${TRIMMOMATIC}'" \
--run-fastqc-start \
--run-fastqc-end

echo "deleting kneaddata uncessary files"
rm $SLURM_TMPDIR/${__sample}/*repeats* $SLURM_TMPDIR/${__sample}/*trimmed*

echo "moving contaminants fastqs to subdir"
mkdir -p $SLURM_TMPDIR/${__sample}/${__sample}_contaminants
mv $SLURM_TMPDIR/${__sample}/*contam*.fastq $SLURM_TMPDIR/${__sample}/${__sample}_contaminants/

echo "concatenate paired output, for HUMAnN single-end run"
cat $SLURM_TMPDIR/${__sample}/${__sample}_paired_1.fastq $SLURM_TMPDIR/${__sample}/${__sample}_paired_2.fastq > $SLURM_TMPDIR/${__sample}/${__sample}_cat-paired.fastq

### Kraken
echo "loading kraken env"
source /project/def-ilafores/common/kraken2/venv/bin/activate
export PATH=/project/def-ilafores/common/kraken2:/project/def-ilafores/common/Bracken:$PATH
export PATH=/project/def-ilafores/common/KronaTools-2.8.1/bin:$PATH

echo "running kraken. Kraken ouptut: $SLURM_TMPDIR/${__sample}/"
kraken2 \
--paired \
--threads '${SLURM_NBR_THREADS}' \
--db '${KRAKEN2_DB_PATH}' \
--use-names \
--output $SLURM_TMPDIR/${__sample}/${__sample}_taxonomy_nt \
--classified-out $SLURM_TMPDIR/${__sample}/${__sample}_classified_reads_#.fastq \
--unclassified-out $SLURM_TMPDIR/${__sample}/${__sample}_unclassified_reads_#.fastq \
--report $SLURM_TMPDIR/${__sample}/${__sample}.kreport \
$SLURM_TMPDIR/${__sample}/${__sample}_paired_1.fastq $SLURM_TMPDIR/${__sample}/${__sample}_paired_2.fastq

### Bracken reestimations
mkdir -p $SLURM_TMPDIR/${__sample}/${__sample}_bracken
echo "running bracken. Bracken Output: $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_S.bracken"

mkdir $SLURM_TMPDIR/${__sample}/${__sample}_kronagrams
for taxa_str in '${TAXONOMIC_LEVEL}'
do
    taxa_oneletter=${taxa_str%%:*}
    taxa_name=${taxa_str#*:}
    echo "running bracken on $taxa. Bracken Output: $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_${taxa_oneletter}.bracken"
    bracken \
    -d '${KRAKEN2_DB_PATH}' \
    -i $SLURM_TMPDIR/${__sample}/${__sample}.kreport \
    -o $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_${taxa_oneletter}.bracken \
    -w $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_bracken_${taxa_oneletter}.kreport \
    -r '$READ_LEN' \
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

	#rm $__EXP_DIR/${__EXP_NAME}_kronagrams/${__EXP_NAME}_${i}.krona
done

python /project/def-ilafores/common/KrakenTools/kreport2mpa.py \
-r $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_bracken_S.kreport \
-o $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_temp.MPA.TXT

grep "|s" $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_temp.MPA.TXT \
| egrep -w -v '"'"'1|2|3|4|5'"'"' - \
| awk '"'"'{printf("%s\t\n", $0)}'"'"' - \
| awk '"'"'BEGIN{printf("#mpa_v30_CHOCOPhlAn_201901\n")}1'"'"' - > $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}-bugs_list.MPA.TXT

#rm temp.MPA.TXT

cp -r $SLURM_TMPDIR/${__sample} '$OUPUT_PATH'



#### old stuff!!


# bracken \
# -d '${KRAKEN2_DB_PATH}' \
# -i $SLURM_TMPDIR/${__sample}/${__sample}.kreport \
# -o $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_S.bracken \
# -w $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_bracken_species.kreport \
# -r '$READ_LEN' \
# -l '$TAXONOMIC_LEVEL'

# echo "creating kronagrams"
# mkdir -p $SLURM_TMPDIR/${__sample}/${__sample}_kronagrams
# echo "running krakentools. Output: $SLURM_TMPDIR/${__sample}/${__sample}_kronagrams/${__sample}_species.krona"
# python /project/def-ilafores/common/KrakenTools/kreport2krona.py \
# -r $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_bracken_species.kreport \
# -o $SLURM_TMPDIR/${__sample}/${__sample}_kronagrams/${__sample}_species.krona
#
# ktImportText \
# $SLURM_TMPDIR/${__sample}/${__sample}_kronagrams/${__sample}_species.krona \
# -o $SLURM_TMPDIR/${__sample}/${__sample}_kronagrams/${__sample}_species.html
#
# #rm $__EXP_DIR/${__EXP_NAME}_kronagrams/${__EXP_NAME}_species.krona
#
# ### ici je crée le fichier du sample; on va merger ces fichiers ensuite.
# ### Le 5 reads or less est un peu arbitraire mais cest ce que Sarah veut pour linstant.
# ### Le awk est nécessaire pour "cheat" humann à reconnaître un fichier pas créé par metaphlan.
# echo "converting kraken report to MPA-style for use as HUMAnN input taxonomic profile"
# python /project/def-ilafores/common/KrakenTools/kreport2mpa.py \
# -r $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_bracken_species.kreport \
# -o $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_temp.MPA.TXT
#
# grep "|s" $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}_temp.MPA.TXT \
# | egrep -w -v '"'"'1|2|3|4|5'"'"' - \
# | awk '"'"'{printf("%s\t\n", $0)}'"'"' - \
# | awk '"'"'BEGIN{printf("#mpa_v30_CHOCOPhlAn_201901\n")}1'"'"' - > $SLURM_TMPDIR/${__sample}/${__sample}_bracken/${__sample}-bugs_list.MPA.TXT
#
# #rm temp.MPA.TXT
#
# cp -r $SLURM_TMPDIR/${__sample} '$OUPUT_PATH'

### finalement, je prends tous les MPA de tous les samples et les combine ainsi :
# __KREPORTS=$(ls boreal_moss/tax_profile_full/*/*_bracken/*species.kreport)
#
# /project/def-ilafores/common/KrakenTools/combine_kreports.py -r $__KREPORTS -o boreal_moss/tax_profile_full/boreal_moss.kreport --only-combined --no-headers

' >> ${OUPUT_PATH}/make_custom_buglist.slurm.sh

echo "To submit to slurm, execute the following command:"
read sample_nbr f <<< $(wc -l ${SAMPLE_TSV})
echo "sbatch --array=1-$sample_nbr ${OUPUT_PATH}/make_custom_buglist.slurm.sh"

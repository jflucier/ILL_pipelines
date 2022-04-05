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
${EXE_PATH}/00_check_makecustom_buglist_environment.sh

newgrp def-ilafores
echo "loading env"
export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6
module use $MUGQIC_INSTALL_HOME/modulefiles

module load StdEnv/2020 gcc/9 python/3.7.9 java/14.0.2 mugqic/bowtie2/2.3.5 mugqic/samtools/1.14 mugqic/usearch/10.0.240
source /project/def-ilafores/common/kraken2/venv/bin/activate
export PATH=/project/def-ilafores/common/kraken2:/project/def-ilafores/common/Bracken:$PATH
export PATH=/project/def-ilafores/common/KronaTools-2.8.1/bin:$PATH

echo "BUGS-LIST CREATION (FOR HUMANN DB CREATION)"
echo "combine all samples kreports in one"
export __KREPORTS=$(ls $OUPUT_PATH/*/*_bracken/*_bracken_S.kreport)
/project/def-ilafores/common/KrakenTools/combine_kreports.py \
-r $__KREPORTS \
-o $OUPUT_PATH/all_samples_S.kreport \
--only-combined --no-headers

echo "convert kreport to mpa"
python /project/def-ilafores/common/KrakenTools/kreport2mpa.py \
-r $OUPUT_PATH/all_samples_S.kreport \
-o $OUPUT_PATH/all_samples_temp_S.MPA.TXT

echo "modify mpa for humann support"
grep "|s" $OUPUT_PATH/all_samples_temp_S.MPA.TXT \
| awk '{printf("%s\t\n", $0)}' - \
| awk 'BEGIN{printf("#mpa_v30_CHOCOPhlAn_201901\n")}1' - > $OUPUT_PATH/all_samples-bugs_list.MPA.TXT


for taxa_str in ${TAXONOMIC_LEVEL}
do
    taxa_oneletter=${taxa_str%%:*}
    taxa_name=${taxa_str#*:}
    echo "JOINT TAXONOMIC TABLES using taxonomic level-specific bracken reestimated abundances for $taxa_name"
    python /project/def-ilafores/common/KrakenTools/combine_mpa.py \
    -i $OUPUT_PATH/*/*_bracken/*_bracken_${taxa_oneletter}.MPA.TXT \
    -o $OUPUT_PATH/temp_${taxa_oneletter}.tsv

    sed -i "s/_bracken_${taxa_oneletter}.kreport//g" $OUPUT_PATH/temp_${taxa_oneletter}.tsv

    if [[ ${taxa_oneletter} == "D" ]]; then
        taxa_oneletter="K";
    fi

    grep -E "(${taxa_oneletter:0:1}__)|(#Classification)" $OUPUT_PATH/temp_${taxa_oneletter}.tsv > $OUPUT_PATH/taxtable_${taxa_oneletter}.tsv
done

#rm $__MOSS_TAX/*/*_bracken/*_bracken_*.MPA.TXT $__MOSS_TAX/temp_*.tsv

echo "done!"

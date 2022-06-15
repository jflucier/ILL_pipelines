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

module load StdEnv/2020 gcc/9 python/3.7.9 java/14.0.2 mugqic/bowtie2/2.3.5 mugqic/samtools/1.14 mugqic/usearch/10.0.240
source /project/def-ilafores/common/kraken2/venv/bin/activate
export PATH=/project/def-ilafores/common/kraken2:/project/def-ilafores/common/Bracken:$PATH
export PATH=/project/def-ilafores/common/KronaTools-2.8.1/bin:$PATH

source $CONF_PARAMETERS

${EXE_PATH}/global.checkenv.sh
${EXE_PATH}/taxonomic_profile.allsample.checkenv.sh

mkdir -p ${OUPUT_PATH}/taxonomic_profile_all

__all_taxas=$(echo "${TAXONOMIC_LEVEL[@]}")


echo "BUGS-LIST CREATION (FOR HUMANN DB CREATION)"
echo "combine all samples kreports in one"
export __KREPORTS=$(ls $TAXONOMIC_ALL_BRACKEN_KREPORTS)
/project/def-ilafores/common/KrakenTools/combine_kreports.py \
-r $__KREPORTS \
-o $OUPUT_PATH/${TAXONOMIC_ALL_NT_DBNAME}_S.kreport \
--only-combined --no-headers

echo "convert kreport to mpa"
python /project/def-ilafores/common/KrakenTools/kreport2mpa.py \
-r $OUPUT_PATH/${TAXONOMIC_ALL_NT_DBNAME}_S.kreport \
-o $OUPUT_PATH/${TAXONOMIC_ALL_NT_DBNAME}_temp_S.MPA.TXT

echo "modify mpa for humann support"
grep "|s" $OUPUT_PATH/${TAXONOMIC_ALL_NT_DBNAME}_temp_S.MPA.TXT \
| awk '{printf("%s\t\n", $0)}' - \
| awk 'BEGIN{printf("#mpa_v30_CHOCOPhlAn_201901\n")}1' - > $OUPUT_PATH/${TAXONOMIC_ALL_NT_DBNAME}-bugs_list.MPA.TXT

for taxa_str in $__all_taxas
do
    taxa_oneletter=${taxa_str%%:*}
    taxa_name=${taxa_str#*:}

    echo "JOINT TAXONOMIC TABLES using taxonomic level-specific bracken reestimated abundances for $taxa_name"

    for report_f in $OUPUT_PATH/*/*_bracken/*_bracken_${taxa_oneletter}.kreport
    do
        python /project/def-ilafores/common/KrakenTools/kreport2mpa.py \
        -r $report_f -o ${report_f//.kreport/}.MPA.TXT --display-header
    done

    echo "runinng combine for $taxa_name"
    python /project/def-ilafores/common/KrakenTools/combine_mpa.py \
    -i $OUPUT_PATH/*/*_bracken/*_bracken_${taxa_oneletter}.MPA.TXT \
    -o $OUPUT_PATH/temp_${taxa_oneletter}.tsv

    sed -i "s/_bracken_${taxa_oneletter}.kreport//g" $OUPUT_PATH/temp_${taxa_oneletter}.tsv

    if [[ ${taxa_oneletter_tmp} == "D" ]]
    then
        taxa_oneletter_tmp="K"
    else
        taxa_oneletter_tmp=${taxa_oneletter_tmp};
    fi

    grep -E "(${taxa_oneletter_tmp:0:1}__)|(#Classification)" $OUPUT_PATH/temp_${taxa_oneletter}.tsv > $OUPUT_PATH/taxtable_${taxa_oneletter}.tsv
done


source /project/def-ilafores/common/humann3/bin/activate
export PATH=/nfs3_ib/ip29-ib/ip29/ilafores_group/programs/diamond-2.0.14/bin:$PATH

### gen python chocphlan cusotm db
cd $OUPUT_PATH
echo "runnin create prescreen db. This step might take long"
python -u ${EXE_PATH}/create_prescreen_db.py $TAXONOMIC_ALL_CHOCOPHLAN_DB $OUPUT_PATH/${TAXONOMIC_ALL_NT_DBNAME}-bugs_list.MPA.TXT
### gen bowtie index on db
mv _custom_chocophlan_database.ffn ${TAXONOMIC_ALL_NT_DBNAME}.ffn
bowtie2-build --threads ${TAXONOMIC_ALL_SLURM_NBR_THREADS} ${TAXONOMIC_ALL_NT_DBNAME}.ffn  ${TAXONOMIC_ALL_NT_DBNAME}

echo "Please move $OUPUT_PATH/${TAXONOMIC_ALL_NT_DBNAME} bowtie index to the location of your custom chocophlan db."
echo "i.e. mv $OUPUT_PATH/${TAXONOMIC_ALL_NT_DBNAME}* /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/humann_dbs/"
echo "Also move $OUPUT_PATH/${TAXONOMIC_ALL_NT_DBNAME}-bugs_list.MPA.TXT to the location of your custom chocophlan db for reference."
echo "i.e. mv $OUPUT_PATH/${TAXONOMIC_ALL_NT_DBNAME}-bugs_list.MPA.TXT /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/humann_dbs/"

echo "humann custom buglist db analysis completed"

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

echo "outputting make custom buglist db slurm script to ${OUPUT_PATH}/make_humann_buglist_db.slurm.sh"
__all_taxas=$(echo "${TAXONOMIC_LEVEL[@]}")

echo '#!/bin/bash' > ${OUPUT_PATH}/make_humann_buglist_db.slurm.sh
echo '
#SBATCH --mail-type=END,FAIL
#SBATCH -D '${OUPUT_PATH}'
#SBATCH -o '${OUPUT_PATH}'/make_humann_buglist_db-%A.slurm.out
#SBATCH --time='${SLURM_WALLTIME}'
#SBATCH --mem='${SLURM_MEMORY}'
#SBATCH -N 1
#SBATCH -n '${SLURM_NBR_THREADS}'
#SBATCH -A '${SLURM_ALLOCATION}'
#SBATCH -J humann_db

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
export __KREPORTS=$(ls '$OUPUT_PATH'/*/*_bracken/*_bracken_S.kreport)
/project/def-ilafores/common/KrakenTools/combine_kreports.py \
-r $__KREPORTS \
-o '$OUPUT_PATH'/'$CUSTOM_CHOCOPHLAN_DB_NAME'_S.kreport \
--only-combined --no-headers

echo "convert kreport to mpa"
python /project/def-ilafores/common/KrakenTools/kreport2mpa.py \
-r '$OUPUT_PATH'/'$CUSTOM_CHOCOPHLAN_DB_NAME'_S.kreport \
-o '$OUPUT_PATH'/'$CUSTOM_CHOCOPHLAN_DB_NAME'_temp_S.MPA.TXT

echo "modify mpa for humann support"
grep "|s" '$OUPUT_PATH'/'$CUSTOM_CHOCOPHLAN_DB_NAME'_temp_S.MPA.TXT \
| awk '"'"'{printf("%s\t\n", $0)}'"'"' - \
| awk '"'"'BEGIN{printf(\"#mpa_v30_CHOCOPhlAn_201901\n\")}1'"'"' - > '$OUPUT_PATH'/'$CUSTOM_CHOCOPHLAN_DB_NAME'-bugs_list.MPA.TXT

for taxa_str in '$__all_taxas'
do
    taxa_oneletter=${taxa_str%%:*}
    taxa_name=${taxa_str#*:}

    echo "JOINT TAXONOMIC TABLES using taxonomic level-specific bracken reestimated abundances for $taxa_name"

    for report_f in '$OUPUT_PATH'/*/*_bracken/*_bracken_${taxa_oneletter}.kreport
    do
        python /project/def-ilafores/common/KrakenTools/kreport2mpa.py \
        -r $report_f -o ${report_f//.kreport/}.MPA.TXT --display-header
    done

    echo "runinng combine for $taxa_name"
    python /project/def-ilafores/common/KrakenTools/combine_mpa.py \
    -i '$OUPUT_PATH'/*/*_bracken/*_bracken_${taxa_oneletter}.MPA.TXT \
    -o '$OUPUT_PATH'/temp_${taxa_oneletter}.tsv

    sed -i "s/_bracken_${taxa_oneletter}.kreport//g" '$OUPUT_PATH'/temp_${taxa_oneletter}.tsv

    if [[ ${taxa_oneletter_tmp} == "D" ]]
    then
        taxa_oneletter_tmp="K"
    else
        taxa_oneletter_tmp=${taxa_oneletter_tmp};
    fi

    grep -E "(${taxa_oneletter_tmp:0:1}__)|(#Classification)" '$OUPUT_PATH'/temp_${taxa_oneletter}.tsv > '$OUPUT_PATH'/taxtable_${taxa_oneletter}.tsv
done


source /project/def-ilafores/common/humann3/bin/activate
export PATH=/nfs3_ib/ip29-ib/ip29/ilafores_group/programs/diamond-2.0.14/bin:$PATH

### gen python chocphlan cusotm db
cd '$OUPUT_PATH'
python '${EXE_PATH}'/create_prescreen_db.py '$CHOCOPHLAN_DB' '$OUPUT_PATH'/'$CUSTOM_CHOCOPHLAN_DB_NAME'-bugs_list.MPA.TXT
### gen bowtie index on db
mv _custom_chocophlan_database.ffn '$CUSTOM_CHOCOPHLAN_DB_NAME'.ffn
bowtie2-build --threads '${SLURM_NBR_THREADS}' '$CUSTOM_CHOCOPHLAN_DB_NAME'.ffn  '$CUSTOM_CHOCOPHLAN_DB_NAME'

echo "Please move '$OUPUT_PATH'/'$CUSTOM_CHOCOPHLAN_DB_NAME' bowtie index to the location of your custom chocophlan db."
echo "i.e. mv '$OUPUT_PATH'/'$CUSTOM_CHOCOPHLAN_DB_NAME'* /nfs3_ib/ip29-ib/ssdpool/private/jflucier/humann_dbs/"
echo "Also move '$OUPUT_PATH'/'$CUSTOM_CHOCOPHLAN_DB_NAME'-bugs_list.MPA.TXT to the location of your custom chocophlan db for reference."
echo "i.e. mv '$OUPUT_PATH'/'$CUSTOM_CHOCOPHLAN_DB_NAME'-bugs_list.MPA.TXT /nfs3_ib/ip29-ib/ssdpool/private/jflucier/humann_dbs/"

echo "humann custom buglist db analysis completed"

' >> ${OUPUT_PATH}/make_humann_buglist_db.slurm.sh

echo "To submit to slurm, execute the following command:"
echo "sbatch ${OUPUT_PATH}/make_humann_buglist_db.slurm.sh"

echo "done!"

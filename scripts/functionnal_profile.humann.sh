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
source /project/def-ilafores/common/humann3/bin/activate
export PATH=/nfs3_ib/ip29-ib/ip29/ilafores_group/programs/diamond-2.0.14/bin:$PATH

source $CONF_PARAMETERS

${EXE_PATH}/global.checkenv.sh
${EXE_PATH}/functionnal_profile.humann.checkenv.sh

mkdir -p ${OUPUT_PATH}/functionnal_profile

export __sample_line=$(cat ${FUNCPROFILING_SAMPLES_LIST_TSV} | awk "NR==$__line_nbr")
export __sample=$(echo -e "$__sample_line" | cut -f1)
export __fastq=$(echo -e "$__sample_line"  | cut -f2)
export __fastq_file=$(basename $__fastq)

echo "copying fastq $__fastq"
cp $__fastq $TMP_DIR/${__fastq_file}

mkdir $TMP_DIR/db
echo "copying nucleotide bowtie index ${FUNCPROFILING_NT_DB}"
export __FUNCPROFILING_NT_DB_BT2=$(basename ${FUNCPROFILING_NT_DB})
cp ${FUNCPROFILING_NT_DB}*.bt2l $TMP_DIR/db/

echo "copying protein diamond index ${FUNCPROFILING_PROT_DB}"
export __PROT_DIA_IDX=$(basename ${FUNCPROFILING_PROT_DB})
cp -r ${FUNCPROFILING_PROT_DB} $TMP_DIR/db

export __FUNCPROFILING_NT_DB=$TMP_DIR/db/${__FUNCPROFILING_NT_DB_BT2}
export __FUNCPROFILING_PROT_DB=$TMP_DIR/db/${__PROT_DIA_IDX}

echo "running humann"
mkdir -p $TMP_DIR/${__sample}
echo "outputting to $TMP_DIR/${__sample}"

mkdir -p ${OUPUT_PATH}/functionnal_profile/${FUNCPROFILING_SEARCH_MODE}

case $FUNCPROFILING_SEARCH_MODE in

  "DUAL")
    echo "Search using DUAL mode"
    humann \
    -v --threads ${FUNCPROFILING_SLURM_NBR_THREADS} \
    --o-log ${OUPUT_PATH}/functionnal_profile/${FUNCPROFILING_SEARCH_MODE}/humann-${__sample}.log \
    --input $TMP_DIR/${__fastq_file} \
    --output $TMP_DIR/${__sample} --output-basename ${__sample} \
    --nucleotide-database $__FUNCPROFILING_NT_DB \
    --protein-database $__FUNCPROFILING_PROT_DB \
    --bypass-prescreen --bypass-nucleotide-index
    ;;

  "NT")
    echo "Search using NT mode"
    humann \
    -v --threads ${FUNCPROFILING_SLURM_NBR_THREADS} \
    --o-log ${OUPUT_PATH}/functionnal_profile/${FUNCPROFILING_SEARCH_MODE}/humann-${__sample}.log \
    --input $TMP_DIR/${__fastq_file} \
    --output $TMP_DIR/${__sample} --output-basename ${__sample} \
    --nucleotide-database $__FUNCPROFILING_NT_DB \
    --bypass-prescreen --bypass-nucleotide-index --bypass-translated-search
    ;;

  "PROT")
    echo "Search using PROT mode"
    humann \
    -v --threads ${FUNCPROFILING_SLURM_NBR_THREADS} \
    --o-log ${OUPUT_PATH}/functionnal_profile/${FUNCPROFILING_SEARCH_MODE}/humann-${__sample}.log \
    --input $TMP_DIR/${__fastq_file} \
    --output $TMP_DIR/${__sample} --output-basename ${__sample} \
    --protein-database $__FUNCPROFILING_PROT_DB \
    --bypass-prescreen --bypass-nucleotide-search
    ;;

  *)
    echo "Provided mode unrecongnised: $FUNCPROFILING_SEARCH_MODE"
    echo "Possible modes are: DUAL, NT or PROT"
    exit 1
    ;;
esac



rm -f $TMP_DIR/${__sample}/*cpm*
rm -f $TMP_DIR/${__sample}/*relab*

echo "running humann rename and regroup table on uniref dbs"
for uniref_db in uniref90_rxn uniref90_go uniref90_ko uniref90_level4ec uniref90_pfam uniref90_eggnog;
do
	if [[ $uniref_db == *"rxn"* ]]; then
		__NAMES=metacyc-rxn
        __MAP=mc-rxn
	elif [[ $uniref_db == *"ko"* ]]; then
		__NAMES=kegg-orthology
        __MAP=kegg
	elif [[ $uniref_db == *"level4ec"* ]]; then
		__NAMES=ec
        __MAP=level4ec
	else
		__NAMES=${uniref_db/uniref90_/}
        __MAP=$__NAMES
	fi

	echo "...regrouping genes to $__NAMES reactions"
	humann_regroup_table \
    --input $TMP_DIR/${__sample}/${__sample}_genefamilies.tsv \
	--output $TMP_DIR/${__sample}/${__sample}_genefamilies_${__MAP}.tsv \
    --groups ${uniref_db}

	echo  "...attaching names to $__MAP codes" ## For convenience
	humann_rename_table \
    --input $TMP_DIR/${__sample}/${__sample}_genefamilies_${__MAP}.tsv \
	--output $TMP_DIR/${__sample}/${__sample}_genefamilies_${__MAP}_named.tsv \
    --names $__NAMES
done

echo "...creating community-level profiles"
rm -fr $TMP_DIR/${__sample}/${__sample}_community_tables/*
mkdir -p $TMP_DIR/${__sample}/${__sample}_community_tables
humann_split_stratified_table \
--input $TMP_DIR/${__sample}/${__sample}_genefamilies.tsv \
--output $TMP_DIR/${__sample}/${__sample}_community_tables/

echo "copying results to ${OUPUT_PATH}/functionnal_profile/${__sample}"
cp -r $TMP_DIR/${__sample} ${OUPUT_PATH}/functionnal_profile/${FUNCPROFILING_SEARCH_MODE}/

echo "done ${__sample}"

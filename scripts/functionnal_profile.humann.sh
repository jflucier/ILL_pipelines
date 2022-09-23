#!/bin/bash

set -e

help_message () {
	echo ""
    echo "Usage: functionnal_profile.humann.sh -s /path/to/tsv --o /path/to/out --nt_db \"nt database path\" [--search_mode \"search mode\"] [--prot_db \"protein database path\"]"
	echo "Options:"

	echo ""
	echo "	-s STR	sample name"
    echo "	-o STR	path to output dir"
    echo "	-tmp STR	path to temp dir (default output_dir/temp)"
    echo "	-t	# of threads (default 8)"
    echo "	-m	memory (default 30G)"
    echo "	-fq	path to fastq"
    echo "	--search_mode	Search mode. Possible values are: dual, nt, prot (default dual)"
    echo "	--nt_db	the nucleotide database to use"
    echo "	--prot_db	the protein database to use (default /project/def-ilafores/common/humann3/lib/python3.7/site-packages/humann/data/uniref)"
    echo "	--log	logging file path (default /path/output/log.txt)"

    echo ""
    echo "  -h --help	Display help"

	echo "";
}

export EXE_PATH=$(dirname "$0")

threads="8"
mem="30G"
sample="false";
out="false";
tmp="false";
fq1="false";
fq2="false";
search_mode="dual"
nt_db="false"
prot_db="/project/def-ilafores/common/humann3/lib/python3.7/site-packages/humann/data/uniref"
log='false'

# load in params
# load in params
SHORT_OPTS="ht:m:o:s:fq1:fq2:tmp:"
LONG_OPTS='help,search_mode,nt_db,prot_db,log'

OPTS=$(getopt -o $SHORT_OPTS --long $LONG_OPTS -- "$@")
# make sure the params are entered correctly
if [ $? -ne 0 ];
then
    help_message;
    exit 1;
fi

while true; do
    # echo $1
	case "$1" in
        -h | --help) help_message; exit 1; shift 1;;
        -t) threads=$2; shift 2;;
        -tmp) tmp=$2; shift 2;;
        -m) mem=$2; shift 2;;
        -s) sample=$2; shift 2;;
        -o) out=$2; shift 2;;
        -fq1) fq1=$2; shift 2;;
		-fq2) fq2=$2; shift 2;;
        --search_mode) search_mode=$2; shift 2;;
		--nt_db) nt_db=$2; shift 2;;
        --prot_db) prot_db=$2; shift 2;;
        --log) prot_db=$2; shift 2;;
        --) help_message; exit 1; shift; break ;;
		*) break;;
	esac
done

if [ "$sample" = "false" ]; then
    echo "Please provide a sample name."
    help_message; exit 1
else
    echo "## Sample name: $sample"
fi

if [ "$search_mode" != "dual" ] && [ "$search_mode" != "nt" ] && [ "$refinement_step" = "prot" ]; then
    echo "Search mode provided is $search_mode. Value must be one of the following: dual, nt or prot"
    help_message; exit 1
fi
echo "## Search mode: $search_mode"

if [ "$out" = "false" ]; then
    echo "Please provide an output path"
    help_message; exit 1
else
    mkdir -p ${out}/${search_mode}
    echo "## Results wil be stored to this path: ${out}/${search_mode}"
fi

if [ "$tmp" = "false" ]; then
    tmp=$out/temp
    mkdir -p $tmp
    echo "## No temp folder provided. Will use: $tmp"
else
    echo "## Temp folder: $tmp"
fi

if [ "$log" = "false" ]; then
    log=${out}/${search_mode}/humann_${__sample}.log
    echo "## Humann log path not specified, will use this path: $log"
else
    echo "## Will output logs in: $log"
fi

if [ "$nt_db" = "false" ]; then
    echo "Please provide an NT db path"
    help_message; exit 1
fi
echo "## NT database: $nt_db"
echo "## Protein database: $prot_db"

echo "analysing sample $sample with metawrap"
echo "fastq1 path: $fq1"
echo "fastq2 path: $fq2"

fq1_name=$(basename $fq1)
fq2_name=$(basename $fq2)

source /project/def-ilafores/common/humann3/bin/activate
export PATH=/nfs3_ib/ip29-ib/ip29/ilafores_group/programs/diamond-2.0.14/bin:$PATH

echo "copying fastq1 $fq1"
cp $fq1 ${tmp}/${fq1_name}
echo "copying fastq2 $fq2"
cp $fq2 ${tmp}/${fq2_name}

mkdir ${tmp}/db
echo "copying nucleotide bowtie index ${nt_db}"
export __nt_db_idx=$(basename ${nt_db})
cp ${nt_db}*.bt2l ${tmp}/db/

echo "copying protein diamond index ${prot_db}"
export __prot_db_idx=$(basename ${prot_db})
cp -r ${prot_db} ${tmp}/db

export __tmp_nt_db=${tmp}/db/${__nt_db_idx}
export __tmp_prot_db=${tmp}/db/${__prot_db_idx}

echo "running humann"
mkdir -p ${tmp}/${__sample}
echo "outputting to ${tmp}/${__sample}"

mkdir -p ${out}/${search_mode}

echo "concatenate paired output, for HUMAnN single-end run"
cat ${tmp}/${fq1_name} ${tmp}/${fq2_name} > $tmp/${sample}_cat-paired.fastq


case $search_mode in

  "DUAL")
    echo "Caslling humann using search mode DUAL"
    humann \
    -v --threads ${threads} \
    --o-log ${log} \
    --input $tmp/${sample}_cat-paired.fastq \
    --output ${tmp}/${__sample} --output-basename ${__sample} \
    --nucleotide-database $__tmp_nt_db \
    --protein-database $__tmp_prot_db \
    --bypass-prescreen --bypass-nucleotide-index
    ;;

  "NT")
  echo "Caslling humann using search mode nt"
    humann \
    -v --threads ${threads} \
    --o-log ${log} \
    --input $tmp/${sample}_cat-paired.fastq \
    --output ${tmp}/${__sample} --output-basename ${__sample} \
    --nucleotide-database $__tmp_nt_db \
    --bypass-prescreen --bypass-nucleotide-index --bypass-translated-search
    ;;

  "PROT")
  echo "Caslling humann using search mode prot"
    humann \
    -v --threads ${threads} \
    --o-log ${log} \
    --input $tmp/${sample}_cat-paired.fastq \
    --output ${tmp}/${__sample} --output-basename ${__sample} \
    --protein-database $__tmp_prot_db \
    --bypass-prescreen --bypass-nucleotide-search
    ;;

  *)
    echo "Provided mode unrecongnised: $search_mode"
    echo "Possible modes are: dual, nt or prot"
    exit 1
    ;;
esac

rm -f ${tmp}/${__sample}/*cpm*
rm -f ${tmp}/${__sample}/*relab*

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
    --input ${tmp}/${__sample}/${__sample}_genefamilies.tsv \
	--output ${tmp}/${__sample}/${__sample}_genefamilies_${__MAP}.tsv \
    --groups ${uniref_db}

	echo  "...attaching names to $__MAP codes" ## For convenience
	humann_rename_table \
    --input ${tmp}/${__sample}/${__sample}_genefamilies_${__MAP}.tsv \
	--output ${tmp}/${__sample}/${__sample}_genefamilies_${__MAP}_named.tsv \
    --names $__NAMES
done

echo "...creating community-level profiles"
rm -fr ${tmp}/${__sample}/${__sample}_community_tables/*
mkdir -p ${tmp}/${__sample}/${__sample}_community_tables
humann_split_stratified_table \
--input ${tmp}/${__sample}/${__sample}_genefamilies.tsv \
--output ${tmp}/${__sample}/${__sample}_community_tables/

echo "copying results to ${out}/${search_mode}"
cp -r ${tmp}/${__sample}/* ${out}/${search_mode}/

echo "done ${__sample}"

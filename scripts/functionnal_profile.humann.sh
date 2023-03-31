#!/bin/bash

set -e

help_message () {
	echo ""
    echo "Usage: functionnal_profile.humann.sh -s sample_name -o /path/to/out --nt_db \"nt database path\" [--search_mode \"search mode\"] [--prot_db \"protein database path\"]"
	echo "Options:"

	echo ""
	echo "	-s STR	sample name"
    echo "	-o STR	path to output dir"
    echo "	-tmp STR	path to temp dir (default output_dir/temp)"
    echo "	-t	# of threads (default 8)"
    echo "	-fq1	path to fastq1"
    echo "	-fq1_single	path to fastq1 unpaired reads"
    echo "	-fq2	path to fastq2"
    echo "	-fq2_single	path to fastq2 unpaired reads"
    echo "	--search_mode	Search mode. Possible values are: dual, nt, prot (default prot)"
    echo "	--nt_db	the nucleotide database to use (default /cvmfs/datahub.genap.ca/vhost34/def-ilafores/humann_dbs/chocophlan)"
    echo "	--prot_db	the protein database to use (default /cvmfs/datahub.genap.ca/vhost34/def-ilafores/humann_dbs/uniref)"

    echo ""
    echo "  -h --help	Display help"

	echo "";
}

export EXE_PATH=$(dirname "$0")

threads="8"
sample="false";
out="false";
tmp="false";
fq1="false";
fq1_single="false";
fq2="false";
fq2_single="false";
search_mode="prot"
nt_db="/cvmfs/datahub.genap.ca/vhost34/def-ilafores/humann_dbs/chocophlan"
prot_db="/cvmfs/datahub.genap.ca/vhost34/def-ilafores/humann_dbs/uniref"
log='false'

# load in params
# load in params
SHORT_OPTS="ht:m:o:s:fq1:fq1_single:fq2:fq2_single:tmp:"
LONG_OPTS='help,search_mode,nt_db,prot_db'

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
        -s) sample=$2; shift 2;;
        -o) out=$2; shift 2;;
        -fq1) fq1=$2; shift 2;;
        -fq1_single) fq1_single=$2; shift 2;;
        -fq2) fq2=$2; shift 2;;
        -fq2_single) fq2_single=$2; shift 2;;
        --search_mode) search_mode=$2; shift 2;;
	      --nt_db) nt_db=$2; shift 2;;
        --prot_db) prot_db=$2; shift 2;;
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

case $search_mode in

  "dual")
    echo "Calling humann using search mode DUAL"
    ;;

  "nt")
  echo "Calling humann using search mode nt"
    ;;

  "prot")
  echo "Calling humann using search mode prot"
    ;;

  *)
    echo "Provided mode unrecongnised: $search_mode"
    echo "Possible modes are: dual, nt or prot"
    help_message; exit 1
    ;;
esac

if [ "$out" = "false" ]; then
    echo "Please provide an output path"
    help_message; exit 1
else
    mkdir -p ${out}
    echo "## Results wil be stored to this path: ${out}"
fi

if [ "$tmp" = "false" ]; then
    tmp=$out/temp
    mkdir -p $tmp
    echo "## No temp folder provided. Will use: $tmp"
else
    echo "## Temp folder: $tmp"
fi

log=${out}/logs/humann_${sample}.log

echo "## NT database: $nt_db"
echo "## Protein database: $prot_db"

if [ "$fq1" = "false" ]; then
    echo "Please provide a fastq1."
    help_message; exit 1
else
    echo "upload $fq1 to $tmp/fq1.fastq"
    cp $fq1 $tmp/fq1.fastq
fi

if [ "$fq1_single" = "false" ]; then
    echo "Since fastq1 single path was not provided. Will not be considered in analysis. "
    touch $tmp/fq1_single.fastq
else
    echo "upload $fq1_single to $tmp/fq1_single.fastq"
    cp $fq1_single $tmp/fq1_single.fastq
fi

if [ "$fq2" = "false" ]; then
    echo "Please provide a fastq2."
    help_message; exit 1
else
    echo "upload $fq2 to $tmp/fq2.fastq"
    cp $fq2 $tmp/fq2.fastq
fi

if [ "$fq2_single" = "false" ]; then
    echo "Since fastq2 single path was not provided. Will not be considered in analysis. "
    touch $tmp/fq2_single.fastq
else
    echo "upload $fq2_single to $tmp/fq2_single.fastq"
    cp $fq2_single $tmp/fq2_single.fastq
fi

echo "copying singularity containers to $tmp"
cp ${EXE_PATH}/../containers/humann.3.6.sif $tmp/

echo "Combining reads to a single fastq"
cat $tmp/fq1.fastq $tmp/fq2.fastq $tmp/fq1_single.fastq $tmp/fq2_single.fastq > $tmp/all_reads.fastq

mkdir -p $tmp/out

case $search_mode in

  "dual")

    echo "Calling humann using search mode DUAL"
    singularity exec --writable-tmpfs -e \
    -B $tmp:$tmp \
    -B $nt_db:$nt_db \
    -B $prot_db:$prot_db \
    $tmp/humann.3.6.sif \
    humann \
    -v --threads ${threads} \
    --o-log ${log} \
    --input $tmp/all_reads.fastq \
    --output $tmp/out --output-basename ${sample} \
    --nucleotide-database $nt_db \
    --protein-database $prot_db \
    --bypass-prescreen --bypass-nucleotide-index
    ;;

  "nt")
  
    echo "Calling humann using search mode nt"
    singularity exec --writable-tmpfs -e \
    -B $tmp:$tmp \
    -B $nt_db:$nt_db \
    $tmp/humann.3.6.sif \
    humann \
    -v --threads ${threads} --resume \
    --o-log ${log} \
    --input $tmp/all_reads.fastq \
    --output --output $tmp/out --output-basename ${sample} \
    --nucleotide-database $nt_db \
    --bypass-prescreen --bypass-nucleotide-index --bypass-translated-search
    ;;

  "prot")

    echo "Calling humann using search mode prot"
    singularity exec --writable-tmpfs -e \
    -B $tmp:$tmp \
    -B $prot_db:$prot_db \
    $tmp/humann.3.6.sif \
    humann \
    -v --threads ${threads} \
    --o-log ${log} \
    --input $tmp/all_reads.fastq \
    --output --output $tmp/out --output-basename ${sample} \
    --protein-database $prot_db \
    --bypass-prescreen --bypass-nucleotide-search
    ;;

  *)
    echo "Provided mode unrecongnised: $search_mode"
    echo "Possible modes are: dual, nt or prot"
    exit 1
    ;;
esac

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
	singularity exec --writable-tmpfs -e \
  -B $tmp:$tmp \
  $tmp/humann.3.6.sif \
  humann_regroup_table \
  --input $tmp/out/${sample}_genefamilies.tsv \
  --output $tmp/out/${sample}_genefamilies_${__MAP}.tsv \
  --groups ${uniref_db}

	echo  "...attaching names to $__MAP codes" ## For convenience
	singularity exec --writable-tmpfs -e \
  -B $tmp:$tmp \
  $tmp/humann.3.6.sif \
  humann_rename_table \
  --input $tmp/out/${sample}_genefamilies_${__MAP}.tsv \
  --output $tmp/out/${sample}_genefamilies_${__MAP}_named.tsv \
  --names $__NAMES
done

echo "...creating community-level profiles"
rm -fr $tmp/out/${sample}_community_tables/*

mkdir -p $tmp/out/${sample}_community_tables
singularity exec --writable-tmpfs -e \
-B $tmp:$tmp \
$tmp/humann.3.6.sif \
humann_split_stratified_table \
--input $tmp/out/${sample}_genefamilies.tsv \
--output $tmp/out/${sample}_community_tables/

echo "copying results to ${out}"
cp -r $tmp/out/* ${out}/

echo "done ${sample}"

#!/bin/bash

set -e

help_message () {
	echo ""
	echo "Usage: taxonomic_profile.allsample.sh [--chocophlan_db /path/to/chocophlan_db ] [--threads nbr_cpu] --kreports '/path/to/*_kraken_report_regex' --out /path/to/out --bowtie_index_name idx_nbame"
	echo "Options:"

	echo ""
	echo "	--kreports STR	base path regex to retrieve species level kraken reports (i.e.: "$PWD"/taxonomic_profile/*/*_bracken/*_bracken_S.kreport). Must be specified between single quotes. See usage example or github documentation."
    echo "	--out STR	path to output dir"
    echo "	--tmp STR	path to temp dir (default output_dir/temp)"
    echo "	--threads	# of threads (default 8)"
    echo "	--bowtie_index_name  name of the bowtie index that will be generated"
    echo "	--chocophlan_db	path to the full chocoplan db (default: /net/nfs-ip34/fast/def-ilafores/humann_dbs/chocophlan)"

    echo ""
    echo "  -h --help	Display help"

	echo "";
}

export EXE_PATH=$(dirname "$0")

# initialisation
kreports='false'
threads="8"
bowtie_idx_name="false";
out="false";
tmp="false";
choco_db="/net/nfs-ip34/fast/def-ilafores/humann_dbs/chocophlan"

# load in params
SHORT_OPTS="h"
LONG_OPTS='help,threads,tmp,kreports,out,bowtie_index_name,chocophlan_db'

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
        --threads) threads=$2; shift 2;;
        --tmp) tmp=$2; shift 2;;
        --kreports) kreports="$2"; shift 2;;
        --out) out=$2; shift 2;;
		    --bowtie_index_name) bowtie_idx_name=$2; shift 2;;
        --chocophlan_db) choco_db=$2; shift 2;;
        --) help_message; exit 1; shift; break ;;
		*) break;;
	esac
done

if [ "$kreports" = "false" ]; then
    echo "Please provide a species taxonomic level kraken report regex."
    help_message; exit 1
fi

kreport_files=$(ls $kreports | wc -l)
if [ $kreport_files -eq 0 ]; then
    echo "Provided species kreport regex $kreports returned 0 report files. Please validate your regex."
    help_message; exit 1
fi

if [ "$out" = "false" ]; then
    echo "Please provide an output path"
    help_message; exit 1
else
    mkdir -p $out
    echo "## Results wil be stored to this path: $out/"
fi

if [ "$tmp" = "false" ]; then
    tmp=$out/temp
    mkdir -p $tmp
    echo "## No temp folder provided. Will use: $tmp"
fi

if [ "$bowtie_idx_name" = "false" ]; then
    echo "Please provide a bowtie index name"
    help_message; exit 1
else
    echo "## Bowtie index will be generated in this path: $out/${bowtie_idx_name}"
fi

echo "BUGS-LIST CREATION (FOR HUMANN DB CREATION)"
kreport_filelist=$(ls $kreports)
basepath="/$(echo \"$kreports\" | cut -d/ -f2)"
echo "combine all species kreports in one using these $kreport_files files: "
echo "$kreport_filelist"

singularity exec --writable-tmpfs -e \
-B $basepath:$basepath \
-B $tmp:/temp \
${EXE_PATH}/../containers/kraken.2.1.2.sif \
python3 /KrakenTools-1.2/combine_kreports.py \
-r $kreport_filelist \
-o /temp/${bowtie_idx_name}_S.kreport \
--only-combined --no-headers

echo "convert kreport to mpa"

singularity exec --writable-tmpfs -e \
-B $basepath:$basepath \
-B $tmp:/temp \
${EXE_PATH}/../containers/kraken.2.1.2.sif \
python3 /KrakenTools-1.2/kreport2mpa.py \
-r /temp/${bowtie_idx_name}_S.kreport \
-o /temp/${bowtie_idx_name}_temp_S.MPA.TXT

echo "modify mpa for humann support"
grep "|s" $tmp/${bowtie_idx_name}_temp_S.MPA.TXT \
| awk '{printf("%s\t\n", $0)}' - \
| awk 'BEGIN{printf("#mpa_v30_CHOCOPhlAn_201901\n")}1' - > $tmp/${bowtie_idx_name}-bugs_list.MPA.TXT

### gen python chocphlan cusotm db
cd $tmp
choco_db_name=$(basename $choco_db)
echo "upload chocophlan db to $tmp/$choco_db_name"
cp -r $choco_db $tmp/$choco_db_name

echo "running create prescreen db. This step might take long"
singularity exec --writable-tmpfs -e \
-H $tmp \
-B ${EXE_PATH}:/code \
-B $tmp:/temp \
${EXE_PATH}/../containers/humann.3.6.sif \
python3 -u /code/create_prescreen_db.py \
$choco_db_name ${bowtie_idx_name}-bugs_list.MPA.TXT

# delete copy of choco
echo "deleting copy of chocophlan db: $tmp/$choco_db_name"
rm -r $tmp/$choco_db_name

### gen bowtie index on db
mkdir $tmp/bowtie_index
mv $tmp/_custom_chocophlan_database.ffn $tmp/bowtie_index/${bowtie_idx_name}.ffn
singularity exec --writable-tmpfs -e \
-B $tmp:$tmp \
${EXE_PATH}/../containers/humann.3.6.sif \
bowtie2-build --threads ${threads} $tmp/bowtie_index/${bowtie_idx_name}.ffn  $tmp/bowtie_index/${bowtie_idx_name}

__all_taxas=(
    "D:domains"
    "P:phylums"
    "C:classes"
    "O:orders"
    "F:families"
    "G:genuses"
    "S:species"
)

basepath=$(echo "$kreports" | perl -ne '
  my @t = split("/",$_);
  pop @t;
  print join("/",@t);
')

mkdir $tmp/taxonomic_table
for taxa_str in "${__all_taxas[@]}"
do
  taxa_oneletter=${taxa_str%%:*}
  taxa_name=${taxa_str#*:}

  report_path="${basepath}/*_bracken_${taxa_oneletter}.kreport"

  echo "## running tax table for $taxa_oneletter using report regex $report_path ##"
  bash ${EXE_PATH}/taxonomic_table.allsamples.sh \
  --kreports "$report_path" \
  --out $tmp/taxonomic_table \
  --tmp $tmp \
  --taxa_code $taxa_oneletter
done

echo "done analysis taxonomic profile on all samples"

echo "copying bowtie index to $out"
cp -fr $tmp/bowtie_index $out/
echo "copying taxonomic table to $out"
cp -fr $tmp/taxonomic_table $out/

echo "humann custom buglist db analysis completed"

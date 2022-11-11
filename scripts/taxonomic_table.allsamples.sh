#!/bin/bash

set -e


help_message () {
	echo ""
	echo "Usage: taxonomic_profile.allsample.sh -i 'kraken_report_regex' -o /path/to/out --nt_dbname mydb "
	echo "Options:"

	echo ""
	echo "	--kreports STR	base path regex to retrieve kreports by taxonomic level. For example, /path/taxonomic_profile/*/*_bracken/*_bracken_P.kreport would retreive all phylums level reports "
	echo "	--taxa_code STR	Taxonomy one letter code (D, P, C, O, F, G, S)"
	echo "	--out STR	path to output dir"
    echo "	--tmp STR	path to temp dir (default output_dir/temp)"

    echo ""
    echo "  -h --help	Display help"

	echo "";
}

export EXE_PATH=$(dirname "$0")

# initialisation
kreports='false'
code='false'
out="false";
tmp="false";

# load in params
SHORT_OPTS="h"
LONG_OPTS='help,taxa_code,kreports,out,tmp'

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
        --tmp) tmp=$2; shift 2;;
        --kreports) kreports="$2"; shift 2;;
		--taxa_code) code="$2"; shift 2;;
        --out) out=$2; shift 2;;
        --) help_message; exit 1; shift; break ;;
		*) break;;
	esac
done

if [ "$kreports" = "false" ]; then
    echo "Please provide a taxonomic level kraken report regex."
    help_message; exit 1
fi

kreport_files=$(ls $kreports | wc -l)
if [ $kreport_files -eq 0 ]
    echo "Provided kreport regex $kreports returned 0 report files. Please validate your regex."
    help_message; exit 1
fi

if [ "$code" = "false" ]; then
    echo "Please provide a taxonomic one letter code for analysis."
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


echo "loading kraken env"
source /project/def-ilafores/common/kraken2/venv/bin/activate
export PATH=/project/def-ilafores/common/kraken2:/project/def-ilafores/common/Bracken:$PATH
export PATH=/project/def-ilafores/common/KronaTools-2.8.1/bin:$PATH

taxa_oneletter=$code

echo "JOINT TAXONOMIC TABLES using taxonomic level-specific bracken reestimated abundances for $taxa_oneletter"
kreport_filelist=$(ls $kreports | wc -l)

for report_f in $kreports
do
	echo "running kreport2mpa on $report_f"
	python /project/def-ilafores/common/KrakenTools/kreport2mpa.py \
	-r $report_f -o ${report_f//.kreport/}.MPA.TXT --display-header
done

echo "runinng combine_mpa for taxonomy $taxa_oneletter"
mpa_reports=${kreports%.kreport}.MPA.TXT
python /project/def-ilafores/common/KrakenTools/combine_mpa.py \
-i $mpa_reports \
-o $tmp/temp_${taxa_oneletter}.tsv

sed -i "s/_bracken_${taxa_oneletter}.kreport//g" $tmp/temp_${taxa_oneletter}.tsv

if [[ ${taxa_oneletter} == "D" ]]
then
    taxa_oneletter_tmp="K"
else
    taxa_oneletter_tmp=${taxa_oneletter};
fi

grep -E "(${taxa_oneletter_tmp:0:1}__)|(#Classification)" $tmp/temp_${taxa_oneletter}.tsv > $tmp/taxtable_${taxa_oneletter}.tsv

echo "copying results back to $out"
cp -fr $tmp/* $out/

echo "taxonomic table generation for $taxa_oneletter completed"

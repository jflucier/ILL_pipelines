#!/bin/bash

set -e

help_message () {
	echo ""
	echo "Usage: taxonomic_profile.sample.sh -s sample_name -o /path/to/out [--db] [--trimmomatic_options \"trim options\"] [--bowtie2_options \"bowtie2 options\"]"
	echo "Options:"

	echo ""
	echo "	-s STR	sample name"
    echo "	-o STR	path to output dir"
    echo "	-tmp STR	path to temp dir (default output_dir/temp)"
    echo "	-t	# of threads (default 8)"
    echo "	-m	memory (default 40G)"
    echo "	-fq1	path to fastq1"
    echo "	-fq2	path to fastq2"
    echo "	--kraken_db	kraken2 database path (default /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/kraken2_dbs/k2_pluspfp_16gb_20210517)"
    echo "	--bracken_readlen	bracken read length option (default 150)"

    echo ""
    echo "  -h --help	Display help"

	echo "";
}

export EXE_PATH=$(dirname "$0")

# initialisation
threads="8"
mem="40G"
sample="false";
out="false";
tmp="false";
fq1="false";
fq2="false";
kraken_db="/nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/kraken2_dbs/k2_pluspfp_16gb_20210517"
bracken_readlen="150"

# load in params
SHORT_OPTS="ht:m:o:s:fq1:fq2:tmp:"
LONG_OPTS='help,kraken_db,bracken_readlen'

OPTS=$(getopt -o $SHORT_OPTS --long $LONG_OPTS -- "$@")
# make sure the params are entered correctly
if [ $? -ne 0 ];
then
    help_message;
    exit 1;
fi

# loop through input params
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
		--db) kraken_db=$2; shift 2;;
        --bracken_readlen) bracken_readlen=$2; shift 2;;
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

echo "analysing sample $sample with metawrap"
echo "fastq1 path: $fq1"
echo "fastq2 path: $fq2"

fq1_name=$(basename $fq1)
fq2_name=$(basename $fq2)

echo "upload fastq1 to $tmp/$fq1_name"
cp $fq1 $tmp/$fq1_name
echo "upload fastq2 to $tmp/$fq2_name"
cp $fq2 $tmp/$fq2_name

### Kraken
echo "loading kraken env"
source /project/def-ilafores/common/kraken2/venv/bin/activate
export PATH=/project/def-ilafores/common/kraken2:/project/def-ilafores/common/Bracken:$PATH
export PATH=/project/def-ilafores/common/KronaTools-2.8.1/bin:$PATH

mkdir $tmp/${sample}
echo "running kraken. Kraken ouptut: $tmp/${sample}/"
kraken2 \
--memory-mapping \
--paired \
--threads ${threads} \
--db ${kraken_db} \
--use-names \
--output $tmp/${sample}/${sample}_taxonomy_nt \
--classified-out $tmp/${sample}/${sample}_classified_reads_#.fastq \
--unclassified-out $tmp/${sample}/${sample}_unclassified_reads_#.fastq \
--report $tmp/${sample}/${sample}.kreport \
$tmp/${fq1_name} $tmp/${fq2_name}

echo "copying all results to $out"
cp -fr $tmp/${sample}/* $out/

### Bracken reestimations
mkdir -p $tmp/${sample}/${sample}_bracken
echo "running bracken. Bracken Output: $tmp/${sample}/${sample}_bracken/${sample}_S.bracken"

mkdir $tmp/${sample}/${sample}_kronagrams

__all_taxas=(
    "D:domains"
    "P:phylums"
    "C:classes"
    "O:orders"
    "F:families"
    "G:genuses"
    "S:species"
)

for taxa_str in $__all_taxas
do
    taxa_oneletter=${taxa_str%%:*}
    taxa_name=${taxa_str#*:}
    echo "running bracken on $taxa. Bracken Output: $tmp/${sample}/${sample}_bracken/${sample}_${taxa_oneletter}.bracken"
    bracken \
    -d ${kraken_db} \
    -i $tmp/${sample}/${sample}.kreport \
    -o $tmp/${sample}/${sample}_bracken/${sample}_${taxa_oneletter}.bracken \
    -w $tmp/${sample}/${sample}_bracken/${sample}_bracken_${taxa_oneletter}.kreport \
    -r $bracken_readlen \
    -l $taxa_oneletter

    echo "creating mpa formatted file for ${taxa_oneletter}"
    python /project/def-ilafores/common/KrakenTools/kreport2mpa.py \
    -r $tmp/${sample}/${sample}_bracken/${sample}_bracken_${taxa_oneletter}.kreport \
    -o $tmp/${sample}/${sample}_bracken/${sample}_bracken_${taxa_oneletter}.MPA.TXT \
    --display-header

    echo "creating kronagrams for ${taxa_oneletter}"
    python /project/def-ilafores/common/KrakenTools/kreport2krona.py \
    -r $tmp/${sample}/${sample}_bracken/${sample}_bracken_${taxa_oneletter}.kreport \
    -o $tmp/${sample}/${sample}_kronagrams/${sample}_${taxa_oneletter}.krona

    echo "generate html from kronagram for ${taxa_oneletter}"
    ktImportText \
		$tmp/${sample}/${sample}_kronagrams/${sample}_${taxa_oneletter}.krona \
		-o $tmp/${sample}/${sample}_kronagrams/${sample}_${taxa_oneletter}.html

done

python /project/def-ilafores/common/KrakenTools/kreport2mpa.py \
-r $tmp/${sample}/${sample}_bracken/${sample}_bracken_S.kreport \
-o $tmp/${sample}/${sample}_bracken/${sample}_temp.MPA.TXT

top_bugs=`wc -l $tmp/${sample}/${sample}_bracken/${sample}_temp.MPA.TXT | awk '{print $1}'`

grep "|s" $tmp/${sample}/${sample}_bracken/${sample}_temp.MPA.TXT \
| sort -k 2 -r -n - \
| head -n $((top_bugs / 50)) - `#selects top 2 percent bugs` \
| awk '{printf("%s\t\n", $0)}' - \
| awk 'BEGIN{printf("#mpa_v30_CHOCOPhlAn_201901\n")}1' - \
> $tmp/${sample}/${sample}-bugs_list.MPA.TXT

echo "copying all results to $out"
cp -fr $tmp/${sample}/* $out/

echo "taxonomic profile done for ${sample}"

#!/bin/bash

set -eEx
trap '__error_handing__ $?' ERR

function __error_handing__(){
    local last_status_code=$1;
    cp -fr $tmp/${sample}/* $out/
    # ${base_out}/.throttle/throttle.start.${sample}.txt
    rm -f ${base_out}/.throttle/throttle.start.${sample}.txt
    rm -f ${base_out}/.throttle/throttle.end.${sample}.txt
    exit $1
}


help_message () {
	echo ""
	echo "Usage: taxonomic_profile.sample.sh [--kraken_db /path/to/krakendb] [--bracken_readlen int] [--confidence float] [-t thread_nbr] [-m mem_in_G] -fq1 /path/fastq1 -fq2 /path/fastq2 -o /path/to/out"
	echo "Options:"

	echo ""
	echo "	-s STR	sample name"
    echo "	-o STR	path to output dir"
    echo "	-tmp STR	path to temp dir (default output_dir/temp)"
    echo "	-t	# of threads (default 8)"
    echo "	-m	memory (default 20G)"
    echo "	-fq1	path to fastq1"
    echo "	-fq2	path to fastq2"
    echo "	--kraken_db	kraken2 database path (default /cvmfs/datahub.genap.ca/vhost34/def-ilafores/kraken2_dbs/k2_pluspfp_16gb_20210517)"
    echo "	--bracken_readlen	bracken read length option (default 150)"
    echo "	--confidence	kraken confidence level to reduce false-positive rate (default 0.05)"

    echo ""
    echo "  -h --help	Display help"

	echo "";
}

export EXE_PATH=$(dirname "$0")

# initialisation
threads="8"
mem="20G"
sample="false";
base_out="false";
tmp="false";
fq1="false";
fq2="false";
kraken_db="/cvmfs/datahub.genap.ca/vhost34/def-ilafores/kraken2_dbs/k2_pluspfp_16gb_20210517"
bracken_readlen="150"
confidence="0.05"

# load in params
SHORT_OPTS="ht:m:o:s:fq1:fq2:tmp:"
LONG_OPTS='help,kraken_db,bracken_readlen,confidence'

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
        -o) base_out=$2; shift 2;;
        -fq1) fq1=$2; shift 2;;
        -fq2) fq2=$2; shift 2;;
		    --kraken_db) kraken_db=$2; shift 2;;
        --confidence) confidence=$2; shift 2;;
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

if [ "$base_out" = "false" ]; then
    echo "Please provide an output path"
    help_message; exit 1
else
    mkdir -p ${base_out}/${sample}
    out=${base_out}/${sample}
    echo "## Results wil be stored to this path: ${out}"
fi

if [ "$tmp" = "false" ]; then
    tmp=$out/temp
    mkdir -p $tmp
    echo "## No temp folder provided. Will use: $tmp"
fi

echo "analysing sample $sample with kraken2 using $confidence confidence level"
echo "fastq1 path: $fq1"
echo "fastq2 path: $fq2"
echo "kraken db: $kraken_db"
echo "running kraken. Kraken ouptut: $tmp/${sample}/"

fq1_name=$(basename $fq1)
fq2_name=$(basename $fq2)
kraken_db_name=$(basename $kraken_db)

mkdir -p ${base_out}/.throttle

# to prevent starting of multiple download because of simultanneneous ls
sleep $[ ( $RANDOM % 30 ) + 1 ]s

l_nbr=$(ls ${base_out}/.throttle/throttle.start.*.txt 2> /dev/null | wc -l )
while [ "$l_nbr" -ge 5 ]
do
  echo "${sample}: compute node copy reached max of 5 parralel copy, will wait 15 sec..."
  sleep 15
  l_nbr=$(ls ${base_out}/.throttle/throttle.start.*.txt 2> /dev/null | wc -l )
done

# add to throttle list
touch ${base_out}/.throttle/throttle.start.${sample}.txt

echo "upload fastq1 to $tmp/$fq1_name"
cp $fq1 $tmp/$fq1_name
echo "upload fastq2 to $tmp/$fq2_name"
cp $fq2 $tmp/$fq2_name
echo "copying singularity containers to $tmp"
cp ${EXE_PATH}/../containers/kraken.2.1.2.sif $tmp/

# remove from throttle list
rm ${base_out}/.throttle/throttle.start.${sample}.txt

mkdir -p $tmp/${sample}
singularity exec --writable-tmpfs -e \
-B $tmp:/temp \
-B $kraken_db:/db \
$tmp/kraken.2.1.2.sif \
kraken2 \
--confidence ${confidence} \
--paired \
--threads ${threads} \
--db /db \
--use-names \
--output /temp/${sample}/${sample}_taxonomy_nt \
--classified-out /temp/${sample}/${sample}_classified_reads_#.fastq \
--unclassified-out /temp/${sample}/${sample}_unclassified_reads_#.fastq \
--report /temp/${sample}/${sample}.kreport \
/temp/${fq1_name} /temp/${fq2_name}

### Bracken reestimations
mkdir -p $tmp/${sample}/${sample}_bracken
mkdir -p $tmp/${sample}/${sample}_kronagrams

__all_taxas=(
    "D:domains"
    "P:phylums"
    "C:classes"
    "O:orders"
    "F:families"
    "G:genuses"
    "S:species"
)

for taxa_str in "${__all_taxas[@]}"
do
    taxa_oneletter=${taxa_str%%:*}
    taxa_name=${taxa_str#*:}
    echo "running bracken on $taxa. Bracken Output: $tmp/${sample}/${sample}_bracken/${sample}_${taxa_oneletter}.bracken"
    singularity exec --writable-tmpfs -e \
    -B $tmp:/temp \
    -B $kraken_db:/db \
    $tmp/kraken.2.1.2.sif \
    bracken \
    -d /db \
    -i /temp/${sample}/${sample}.kreport \
    -o /temp/${sample}/${sample}_bracken/${sample}_${taxa_oneletter}.bracken \
    -w /temp/${sample}/${sample}_bracken/${sample}_bracken_${taxa_oneletter}.kreport \
    -r $bracken_readlen \
    -l $taxa_oneletter

    echo "creating mpa formatted file for ${taxa_oneletter}"
    singularity exec --writable-tmpfs -e \
    -B $tmp:/temp \
    $tmp/kraken.2.1.2.sif \
    python3 /KrakenTools-1.2/kreport2mpa.py \
    -r /temp/${sample}/${sample}_bracken/${sample}_bracken_${taxa_oneletter}.kreport \
    -o /temp/${sample}/${sample}_bracken/${sample}_bracken_${taxa_oneletter}.MPA.TXT \
    --display-header

    echo "creating kronagrams for ${taxa_oneletter}"
    singularity exec --writable-tmpfs -e \
    -B $tmp:/temp \
    $tmp/kraken.2.1.2.sif \
    python3 /KrakenTools-1.2/kreport2krona.py \
    -r /temp/${sample}/${sample}_bracken/${sample}_bracken_${taxa_oneletter}.kreport \
    -o /temp/${sample}/${sample}_kronagrams/${sample}_${taxa_oneletter}.krona

    echo "generate html from kronagram for ${taxa_oneletter}"
    singularity exec --writable-tmpfs -e \
    -B $tmp:/temp \
    $tmp/kraken.2.1.2.sif \
    ktImportText \
		/temp/${sample}/${sample}_kronagrams/${sample}_${taxa_oneletter}.krona \
		-o /temp/${sample}/${sample}_kronagrams/${sample}_${taxa_oneletter}.html

done

singularity exec --writable-tmpfs -e \
-B $tmp:/temp \
$tmp/kraken.2.1.2.sif \
python3 /KrakenTools-1.2/kreport2mpa.py \
-r /temp/${sample}/${sample}_bracken/${sample}_bracken_S.kreport \
-o /temp/${sample}/${sample}_bracken/${sample}_temp.MPA.TXT

top_bugs=`wc -l $tmp/${sample}/${sample}_bracken/${sample}_temp.MPA.TXT | awk '{print $1}'`

grep "|s" $tmp/${sample}/${sample}_bracken/${sample}_temp.MPA.TXT \
| sort -k 2 -r -n - \
| head -n $((top_bugs / 50)) - `#selects top 2 percent bugs` \
| awk '{printf("%s\t\n", $0)}' - \
| awk 'BEGIN{printf("#mpa_v30_CHOCOPhlAn_201901\n")}1' - \
> $tmp/${sample}/${sample}-bugs_list.MPA.TXT


echo "copying results to ${base_out} with throttling"

l_nbr=$(ls ${base_out}/.throttle/throttle.end.*.txt 2> /dev/null | wc -l )
while [ "$l_nbr" -ge 5 ]
do
  echo "${sample}: compute node copy reached max of 5 parralel copy, will wait 15 sec..."
  sleep 15
  l_nbr=$(ls ${base_out}/.throttle/throttle.end.*.txt 2> /dev/null | wc -l )
done

# add to throttle list
touch ${base_out}/.throttle/throttle.end.${sample}.txt

cp -fr $tmp/${sample}/* $out/

# cp done remove from list
rm ${base_out}/.throttle/throttle.end.${sample}.txt

echo "taxonomic profile done for ${sample}"

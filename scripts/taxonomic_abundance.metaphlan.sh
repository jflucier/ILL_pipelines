#!/bin/bash -l

set -eEx
trap '__error_handing__ $?' ERR

function __error_handing__(){
    local last_status_code=$1;
    # ${base_out}/.throttle/throttle.start.${sample}.txt
    rm -f ${base_out}/.throttle/throttle.start.${sample}.txt
    rm -f ${base_out}/.throttle/throttle.end.${sample}.txt
    exit $1
}

help_message () {
  echo ""
  echo "Usage: taxonomic_abundance.metaphlan.sh -s sample_name -o /path/to/out [-db /path/to/metaphlan/db] -fq1 /path/to/fastq1 -fq2 /path/to/fastq2 [-fq1_single /path/to/single1.fastq] [-fq2_single /path/to/single2.fastq]"
  echo "Options:"

  echo ""
  echo "	-s STR	sample name"
  echo "	-o STR	path to output dir"
  echo "	-tmp STR	path to temp dir (default output_dir/temp)"
  echo "	-t	# of threads (default 4)"
  echo "	-fq1	path to fastq1"
  echo "	-fq1_single	path to fastq1 unpaired reads"
  echo "	-fq2	path to fastq2"
  echo "	-fq2_single	path to fastq2 unpaired reads"
  echo "	-db	metaphlan db path (default /cvmfs/datahub.genap.ca/vhost34/def-ilafores/metaphlan4_db/mpa_vOct22_CHOCOPhlAnSGB_202212)"

  echo ""
  echo "  -h --help	Display help"

	echo "";
}

export EXE_PATH=$(dirname "$0")

# initialisation
threads="4"
sample="false";
base_out="false";
tmp="false";
fq1="false";
fq1_single="false";
fq2="false";
fq2_single="false";
db="/cvmfs/datahub.genap.ca/vhost34/def-ilafores/metaphlan4_db/mpa_vOct22_CHOCOPhlAnSGB_202212"

# load in params
SHORT_OPTS="ht:o:s:fq1:fq1_single:fq2:fq2_single:db:tmp:"
LONG_OPTS='help'

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
        -s) sample=$2; shift 2;;
        -o) base_out=$2; shift 2;;
        -fq1) fq1=$2; shift 2;;
        -fq1_single) fq1_single=$2; shift 2;;
        -fq2) fq2=$2; shift 2;;
        -fq2_single) fq2_single=$2; shift 2;;
		    -db) db=$2; shift 2;;
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

if [ "$fq1" = "false" ]; then
    echo "Please provide a fastq1."
    help_message; exit 1
fi

if [ "$fq1_single" = "false" ]; then
    echo "Since fastq1 single path was not provided. Will not be considered in analysis. "
    touch $tmp/fq1_single.fastq
    fq1_single=$tmp/fq1_single.fastq
fi

if [ "$fq2" = "false" ]; then
    echo "Please provide a fastq2."
    help_message; exit 1
fi

if [ "$fq2_single" = "false" ]; then
    echo "Since fastq2 single path was not provided. Will not be considered in analysis. "
    touch $tmp/fq2_single.fastq
    fq2_single=$tmp/fq2_single.fastq
fi

# throttling
mkdir -p $base_out/.throttle

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

echo "upload $fq1 to $tmp/fq1.fastq"
cp $fq1 $tmp/fq1.fastq
echo "upload $fq2 to $tmp/fq2.fastq"
cp $fq2 $tmp/fq2.fastq
echo "upload $fq1_single to $tmp/fq1_single.fastq"
cp $fq1_single $tmp/fq1_single.fastq
echo "upload $fq2_single to $tmp/fq2_single.fastq"
cp $fq2_single $tmp/fq2_single.fastq
echo "copying singularity containers to $tmp"
cp ${EXE_PATH}/../containers/humann.3.6.sif $tmp/

# remove from throttle list
rm ${base_out}/.throttle/throttle.start.${sample}.txt

echo "Combining reads to a single fastq"
cat $tmp/fq1.fastq $tmp/fq2.fastq $tmp/fq1_single.fastq $tmp/fq2_single.fastq > $tmp/all_reads.fastq

echo "analysing sample $sample using metaphlan against $db index"
db_index=$(basename $db)
db_path=$(dirname $db)
singularity exec --writable-tmpfs -e \
-B $tmp:$tmp \
-B $db_path:$db_path \
$tmp/humann.3.6.sif \
metaphlan \
-t rel_ab \
--input_type fastq --add_viruses --unclassified_estimation --offline \
--tmp_dir $tmp \
--bowtie2db $db_path \
-x $db_index \
--bowtie2out $tmp/${sample}.bowtie2.txt \
--nproc $threads \
-o $tmp/${sample}_profile.txt \
$tmp/all_reads.fastq

echo "copying results to $out with throttling"

l_nbr=$(ls ${base_out}/.throttle/throttle.end.*.txt 2> /dev/null | wc -l )
while [ "$l_nbr" -ge 5 ]
do
  echo "${sample}: compute node copy reached max of 5 parralel copy, will wait 15 sec..."
  sleep 15
  l_nbr=$(ls ${base_out}/.throttle/throttle.end.*.txt 2> /dev/null | wc -l )
done

# add to throttle list
touch ${base_out}/.throttle/throttle.end.${sample}.txt

cp $tmp/${sample}.bowtie2.txt ${out}/
cp $tmp/${sample}_profile.txt ${out}/

# cp done remove from list
rm ${base_out}/.throttle/throttle.end.${sample}.txt

echo "Metaphlan taxonomic abundance of ${sample} completed!"

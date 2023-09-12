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
  echo "Usage: taxonomic_abundance.sourmash.sh -s sample_name -o /path/to/out [-t threads] -fq1 /path/to/fastq1 -fq2 /path/to/fastq2 [--SM_db /path/to/sourmash/db] [--SM_db_prefix sourmash_db_prefix] [--kmer kmer_size]"
  echo "Options:"

  echo ""
  echo "	-s STR	sample name"
  echo "	-o STR	path to output dir"
  echo "	-tmp STR	path to temp dir (default output_dir/temp)"
  echo "	-t	# of threads (default 2)"
  echo "	-fq1	path to fastq1"
  echo "	-fq2	path to fastq2"
  echo "	--SM_db	sourmash databases directory path (default /cvmfs/datahub.genap.ca/vhost34/def-ilafores/sourmash_db/)"
  echo "	--SM_db_prefix	sourmash database prefix, allowing wildcards (default genbank-2022.03)"
  echo "	--kmer	choice of k-mer size, dependent on available databases (default 51, make sure database is available)"

  echo ""
  echo "  -h --help	Display help"

	echo "";
}

export EXE_PATH=$(dirname "$0")

# initialisation
threads="2"
sample="false";
base_out="false";
tmp="false";
fq1="false";
fq2="false";
SM_db="/cvmfs/datahub.genap.ca/vhost34/def-ilafores/sourmash_db"
SM_db_prefix="genbank-2022.03"
kmer="51"

# load in params
SHORT_OPTS="ht:o:s:fq1:fq2:tmp:"
LONG_OPTS='help,SM_db,SM_db_prefix,kmer'

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
        -fq2) fq2=$2; shift 2;;
		    --SM_db) SM_db=$2; shift 2;;
        --SM_db_prefix) SM_db_prefix=$2; shift 2;;
        --kmer) kmer=$2; shift 2;;
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

echo "fastq1 path: $fq1"
echo "fastq2 path: $fq2"

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

fq1_name=$(basename $fq1)
fq2_name=$(basename $fq2)

echo "upload fastq1 to $tmp/$fq1_name"
cp $fq1 $tmp/$fq1_name
echo "upload fastq2 to $tmp/$fq2_name"
cp $fq2 $tmp/$fq2_name
echo "copying singularity containers to $tmp"
cp ${EXE_PATH}/../containers/sourmash.4.7.0.sif $tmp/

# remove from throttle list
rm ${base_out}/.throttle/throttle.start.${sample}.txt

### Sourmash
echo "analysing sample $sample containment using sourmash against ${SM_db_prefix}.k${kmer} index"

mkdir -p $tmp/${sample}
echo "...generate sample fracminhash sketch with sourmash sketch"
singularity exec --writable-tmpfs -e \
-B $tmp:$tmp \
$tmp/sourmash.4.7.0.sif \
sourmash sketch dna \
-p k=$kmer,scaled=1000,abund \
--merge $sample \
-o $tmp/${sample}/${sample}.k${kmer}.sig \
$tmp/${fq1_name} \
$tmp/${fq2_name}

echo "...determine metagenome composition using sourmash gather"
singularity exec --writable-tmpfs -e \
-B $tmp:$tmp \
-B $SM_db:$SM_db \
$tmp/sourmash.4.7.0.sif \
sourmash gather \
$tmp/${sample}/${sample}.k${kmer}.sig \
$SM_db/${SM_db_prefix}*k${kmer}.zip \
-o $tmp/${sample}/${sample}.k${kmer}.csv

echo "...assign taxonomy using sourmash taxonomy"
singularity exec --writable-tmpfs -e \
-B $tmp:$tmp \
-B $SM_db:$SM_db \
$tmp/sourmash.4.7.0.sif \
sourmash tax annotate \
-g $tmp/${sample}/${sample}.k${kmer}.csv \
-t $SM_db/${SM_db_prefix}*.sqldb \
-o $tmp/${sample}
				
echo "copying results to ${out}/taxSM_${SM_db_prefix}_k${kmer} with throttling"

l_nbr=$(ls ${base_out}/.throttle/throttle.end.*.txt 2> /dev/null | wc -l )
while [ "$l_nbr" -ge 5 ]
do
  echo "${sample}: compute node copy reached max of 5 parralel copy, will wait 15 sec..."
  sleep 15
  l_nbr=$(ls ${base_out}/.throttle/throttle.end.*.txt 2> /dev/null | wc -l )
done

# add to throttle list
touch ${base_out}/.throttle/throttle.end.${sample}.txt

mkdir -p ${out}/taxSM_${SM_db_prefix}_k${kmer}
cp -fr $tmp/${sample}/* ${out}/taxSM_${SM_db_prefix}_k${kmer}/

# cp done remove from list
rm ${base_out}/.throttle/throttle.end.${sample}.txt

echo "taxonomic profile of ${sample} completed!"

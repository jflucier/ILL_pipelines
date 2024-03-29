#!/bin/bash

set -eEx
trap '__error_handing__ $?' ERR

function __error_handing__(){
    local last_status_code=$1;
    rm -f ${base_out}/.throttle/throttle.start.${sample}.txt
    rm -f ${base_out}/.throttle/throttle.end.${sample}.txt
    exit $1
}

help_message () {
	echo ""
	echo "Usage: bin_refinement.metawrap.sh [-tmp /path/tmp] [-t threads] [-m memory] [--metaspades] [--megahit] -s sample_name -o /path/to/out -fq1 /path/to/fastq1 -fq2 /path/to/fastq2 "
	echo "Options:"

	echo ""
	echo "	-s STR	sample name"
    echo "	-o STR	path to output dir"
    echo "	-tmp STR	path to temp dir (default output_dir/temp)"
    echo "	-t	# of threads (default 8)"
    echo "	-m	memory (default 40G)"
    echo "	--metabat2_bins	path to metabats bin directory"
    echo "	--maxbin2_bins	path to maxbin2 bin directory"
    echo "	--concoct_bins	path to concoct bin direcotory"
    echo "	--refinement_min_compl INT	refinement bin minimum completion percent (default 50)"
    echo "	--refinement_max_cont INT	refinement bin maximum contamination percent (default 10)"
    echo ""
    echo "  -h --help	Display help"

	echo "";
}

export EXE_PATH=$(dirname "$0")

# initialisation
threads="8"
mem="30G"
sample="false";
base_out="false";
tmp="false";
metabat2_bins="false";
maxbin2_bins="false";
concoct_bins="false"
refinement_min_compl="50";
refinement_max_cont="10";

# load in params
SHORT_OPTS="ht:m:o:s:tmp:"
LONG_OPTS='help,metabat2_bins,maxbin2_bins,concoct_bins,refinement_min_compl,refinement_max_cont'

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
        -o) base_out=$2; shift 2;;
        --metabat2_bins) metabat2_bins=$2; shift 2;;
		--maxbin2_bins) maxbin2_bins=$2; shift 2;;
        --concoct_bins) concoct_bins=$2; shift 2;;
        --refinement_min_compl) refinement_min_compl=$2; shift 2;;
        --refinement_max_cont) refinement_max_cont=$2; shift 2;;
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
    mkdir -p ${base_out}/refinement/${sample}
    out=${base_out}/refinement/${sample}
    echo "## Results wil be stored to this path: ${out}"
fi

if [ "$tmp" = "false" ]; then
    tmp=$out/temp
    mkdir -p $tmp
    echo "## No temp folder provided. Will use: $tmp"
fi

if [ "$metabat2_bins" = "false" ]; then
    echo "Please provide a metabat2 bins path"
    help_message; exit 1
else
    echo "## Will use metabat2 bins path: $metabat2_bins/"
fi

if [ "$maxbin2_bins" = "false" ]; then
    echo "Please provide a maxbin2 bins path"
    help_message; exit 1
else
    echo "## Will use maxbin2 bins path: $maxbin2_bins/"
fi

if [ "$concoct_bins" = "false" ]; then
    echo "Please provide a concoct bins path"
    help_message; exit 1
else
    echo "## Will use concoct bins path: $concoct_bins/"
fi

echo "## Will use minimum completion percent: $refinement_min_compl/"
echo "## Will use maximum contamination percent: $refinement_max_cont/"

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

echo "copying metabat2 bins in temps dir"
mkdir ${tmp}/metabat2_bins
cp -r $metabat2_bins/* ${tmp}/metabat2_bins/
echo "copying maxbin2 bins in temps dir"
mkdir ${tmp}/maxbin2_bins
cp -r $maxbin2_bins/* ${tmp}/maxbin2_bins/
echo "copying concoct bins in temps dir"
mkdir ${tmp}/concoct_bins
cp -r $concoct_bins/* ${tmp}/concoct_bins/
echo "cp singularity container to $tmp"
cp ${EXE_PATH}/../containers/metawrap.1.3.sif $tmp/

# remove from throttle list
rm ${base_out}/.throttle/throttle.start.${sample}.txt

echo "Running metawrap bin refinement"
mkdir ${tmp}/bin_refinement/
export BINNING_MEM=$(echo $mem | perl -ne 'chomp($_); chop($_); print $_ . "\n";')
singularity exec --writable-tmpfs -e \
-B ${tmp}:/out \
-B /nfs3_ib/nfs-ip34/fast/def-ilafores/checkm_db:/checkm \
-B /nfs3_ib/nfs-ip34/fast/def-ilafores/NCBI_nt:/NCBI_nt \
-B /nfs3_ib/nfs-ip34/fast/def-ilafores/NCBI_tax:/NCBI_tax \
$tmp/metawrap.1.3.sif \
metawrap bin_refinement -t $threads -m $BINNING_MEM --quick \
-c $refinement_min_compl -x $refinement_max_cont \
-o /out/bin_refinement/ \
-A /out/metabat2_bins/ \
-B /out/maxbin2_bins/ \
-C /out/concoct_bins/

sed '1s/$/\tsampID/;2,$s/$/\t'${sample}'/' ${tmp}/bin_refinement/metawrap_${refinement_min_compl}_${refinement_max_cont}_bins.stats > ${tmp}/bin_refinement/${sample}_refined.stats

echo "adding sample name to bin filename"
for bin in ${tmp}/bin_refinement/metawrap_${refinement_min_compl}_${refinement_max_cont}_bins/*.fa
do
  b=$(basename $bin)
  mv $bin ${tmp}/bin_refinement/metawrap_${refinement_min_compl}_${refinement_max_cont}_bins/${sample}.${b}
done

echo "copying bin_refinement results back to $out"

echo "copying results to $out with throttling"
mkdir -p $out/

l_nbr=$(ls ${base_out}/.throttle/throttle.end.*.txt 2> /dev/null | wc -l )
while [ "$l_nbr" -ge 5 ]
do
  echo "${sample}: compute node copy reached max of 5 parralel copy, will wait 15 sec..."
  sleep 15
  l_nbr=$(ls ${base_out}/.throttle/throttle.end.*.txt 2> /dev/null | wc -l )
done

# add to throttle list
touch ${base_out}/.throttle/throttle.end.${sample}.txt

cp -r ${tmp}/bin_refinement/* $out/

# cp done remove from list
rm ${base_out}/.throttle/throttle.end.${sample}.txt

echo "metawrap binning refinement pipeline done"

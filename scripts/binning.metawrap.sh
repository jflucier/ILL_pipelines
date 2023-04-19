#!/bin/bash

set -e

help_message () {
	echo ""
	echo "Usage: binning.metawrap.sh [-tmp /path/tmp] [-t threads] [-m memory] [--metabat2] [--maxbin2] [--concoct] [--run-checkm] -s sample_name -o /path/to/out -a /path/to/assembly -fq1 /path/to/fastq1 -fq2 /path/to/fastq2 "
	echo "Options:"

	echo ""
	echo "	-s STR	sample name"
    echo "	-o STR	path to output dir"
    echo "	-tmp STR	path to temp dir (default output_dir/temp)"
    echo "	-t	# of threads (default 8)"
    echo "	-m	memory (default 40G)"
    echo "	-a	assembly fasta filepath"
    echo "	-fq1	path to fastq1"
    echo "	-fq2	path to fastq2"
    echo "	--metabat2	use metabat2 for binning (default: true)"
    echo "	--maxbin2	use maxbin2 for binning (default: true)"
    echo "	--concoct	use concoct for binning (default: true)"
    echo "	--run-checkm	run checkm on bins (default: true)"
    echo ""
    echo "  -h --help	Display help"

	echo "";
}

set_binning_options () {

    binning_programs="--metabat2 --maxbin2 --concoct --run-checkm"
    # set_binning_options $binning_metabat2 $binning_maxbin2 $binning_concoct $binning_run_checkm

    if [ "$1" = "true" ] || [ "$2" = "true" ] || [ "$3" = "true" ] ; then
        binning_programs=""
        if [ "$1" = "true" ] ; then
            binning_programs="--metabat2"
        fi

        if [ "$2" = "true" ] ; then
            binning_programs="$binning_programs --maxbin2"
        fi

        if [ "$3" = "true" ] ; then
            binning_programs="$binning_programs --concoct"
        fi

        if [ "$4" = "true" ] ; then
            binning_programs="$binning_programs --run-checkm"
        fi
    fi

    echo "# Will use the following binning programs: $binning_programs"
}

export EXE_PATH=$(dirname "$0")

# initialisation
threads="8"
mem="30G"
sample="false";
base_out="false";
tmp="false";
fq1="false";
fq2="false";
ass="false"
metabat2="false";
maxbin2="false";
concoct="false"
run_checkm="false"


# load in params
SHORT_OPTS="ht:m:o:s:fq1:fq2:tmp:a:"
LONG_OPTS='help,metabat2,maxbin2,concoct,run-checkm'

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
        -a) ass=$2; shift 2;;
        -fq1) fq1=$2; shift 2;;
        -fq2) fq2=$2; shift 2;;
        --metabat2) metabat2=true; shift 1;;
		    --maxbin2) maxbin2=true; shift 1;;
        --concoct) concoct=true; shift 1;;
        --run-checkm) run_checkm=true; shift 1;;
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

if [ "$ass" = "false" ]; then
    echo "Please provide assembly fasta."
    help_message; exit 1
else
    echo "## Assembly fasta: $ass"
fi

if [ "$base_out" = "false" ]; then
    echo "Please provide an output path"
    help_message; exit 1
else
    mkdir -p ${base_out}/binning/${sample}
    out=${base_out}/binning/${sample}
    echo "## Results wil be stored to this path: ${out}"
fi

if [ "$tmp" = "false" ]; then
    tmp=$out/temp
    mkdir -p $tmp
    echo "## No temp folder provided. Will use: $tmp"
fi

# set assembly options
binning_programs="--metabat2 --maxbin2 --concoct --run-checkm"
set_binning_options $metabat2 $maxbin2 $concoct $run_checkm

echo "analysing sample $sample with metawrap"
echo "fastq1 path: $fq1"
echo "fastq2 path: $fq2"

fq1_name=$(basename $fq1)
fq2_name=$(basename $fq2)
ass_name=$(basename $ass)

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

echo "upload fastq1 to $tmp/"
cp $fq1 $tmp/$fq1_name
echo "upload fastq2 to $tmp"
cp $fq2 $tmp/$fq2_name
echo "copying assembly fasta in temps dir"
cp -r $ass ${tmp}/$ass_name
echo "cp singularity container to $tmp"
cp ${EXE_PATH}/../containers/metawrap.1.3.sif $tmp/

# remove from throttle list
rm ${base_out}/.throttle/throttle.start.${sample}.txt

mkdir -p ${tmp}/binning

echo "binning sample $sample with metawrap"
# around 9hr of exec
echo "metawrap binning and checkm step using metabat2, maxbin2 and concoct"
export BINNING_MEM=$(echo $mem | perl -ne 'chomp($_); chop($_); print $_ . "\n";')
singularity exec --writable-tmpfs -e \
-B ${tmp}:/out \
-B /net/nfs-ip34/fast/def-ilafores/checkm_db:/checkm \
-B /net/nfs-ip34/fast/def-ilafores/NCBI_nt:/NCBI_nt \
-B /net/nfs-ip34/fast/def-ilafores/NCBI_tax:/NCBI_tax \
$tmp/metawrap.1.3.sif \
metaWRAP binning $binning_programs \
-m $BINNING_MEM -t $threads \
-a /out/$ass_name \
-o /out/binning/ \
/out/$fq1_name /out/$fq2_name

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

cp -r ${tmp}/binning/* $out/

# cp done remove from list
rm ${base_out}/.throttle/throttle.end.${sample}.txt

echo "metawrap binning done"

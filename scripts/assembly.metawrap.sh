#!/bin/bash

set -e

help_message () {
	echo ""
	echo "Usage: assembly.metawrap.sh [-tmp /path/tmp] [-t threads] [-m memory] [--metaspades] [--megahit] -s sample_name -o /path/to/out -fq1 /path/to/fastq1 -fq2 /path/to/fastq2 "
	echo "Options:"

	echo ""
	echo "	-s STR	sample name"
    echo "	-o STR	path to output dir"
    echo "	-tmp STR	path to temp dir (default output_dir/temp)"
    echo "	-t	# of threads (default 8)"
    echo "	-m	memory (default 40G)"
    echo "	-fq1	path to fastq1"
    echo "	-fq2	path to fastq2"
    echo "	--metaspades	use metaspades for assembly (default: true)"
    echo "	--megahit	use megahit for assembly (default: true)"
    echo ""
    echo "  -h --help	Display help"

	echo "";
}

set_assembly_options () {

    assembly_programs="--metaspades --megahit"
    # set_assembly_options $assembly_metaspades $assembly_megahit

    if [ "$1" = "true" ] || [ "$2" = "true" ] ; then
        assembly_programs=""
        if [ "$1" = "true" ] ; then
            assembly_programs="--metaspades"
        fi

        if [ "$2" = "true" ] ; then
            assembly_programs="$assembly_programs --megahit"
        fi
    fi

    echo "# Will use the following assembly programs: $assembly_programs"
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
assembly_metaspades="false";
assembly_megahit="false";

# load in params
SHORT_OPTS="ht:m:o:s:fq1:fq2:tmp:"
LONG_OPTS='help,metaspades,megahit'

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
        --metaspades) assembly_metaspades=true; shift 1;;
		--megahit) assembly_megahit=true; shift 1;;
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
    mkdir -p ${base_out}/assembly/${sample}
    out=${base_out}/assembly/${sample}
    echo "## Results wil be stored to this path: ${out}"
fi


if [ "$tmp" = "false" ]; then
    tmp=$out/temp
    mkdir -p $tmp
    echo "## No temp folder provided. Will use: $tmp"
fi

# set assembly options
assembly_programs="--metaspades --megahit"
set_assembly_options $assembly_metaspades $assembly_megahit

echo "analysing sample $sample with metawrap"
echo "fastq1 path: $__fastq_file1"
echo "fastq2 path: $__fastq_file2"

fq1_name=$(basename $fq1)
fq2_name=$(basename $fq2)

# throttling
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

echo "upload fastq1 to $tmp/"
cp $fq1 $tmp/$fq1_name
echo "upload fastq2 to $tmp"
cp $fq2 $tmp/$fq2_name
echo "cp singularity container to $tmp"
cp ${EXE_PATH}/../containers/metawrap.1.3.sif $tmp/

# remove from throttle list
rm ${base_out}/.throttle/throttle.start.${sample}.txt

mkdir -p ${tmp}/assembly

echo "running BBmap repair.sh"
singularity exec --writable-tmpfs -e \
-B ${tmp}:/out \
$tmp/metawrap.1.3.sif \
repair.sh \
in=/out/$fq1_name \
in2=/out/$fq2_name \
out=/out/${sample}_paired_sorted_1.fastq \
out2=/out/${sample}_paired_sorted_2.fastq

echo "metawrap assembly step using ${assembly_programs}"

export SPADES_MEM=$(echo $mem | perl -ne 'chomp($_); chop($_); print $_ . "\n";')
singularity exec --writable-tmpfs -e \
-B ${tmp}:/out \
-B /net/nfs-ip34/fast/def-ilafores/checkm_db:/checkm \
-B /net/nfs-ip34/fast/def-ilafores/NCBI_nt:/NCBI_nt \
-B /net/nfs-ip34/fast/def-ilafores/NCBI_tax:/NCBI_tax \
$tmp/metawrap.1.3.sif \
metaWRAP assembly ${assembly_programs} \
-m $SPADES_MEM -t $threads \
-1 /out/${sample}_paired_sorted_1.fastq \
-2 /out/${sample}_paired_sorted_2.fastq \
-o /out/assembly/

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

cp -r ${tmp}/assembly/* $out

# cp done remove from list
rm ${base_out}/.throttle/throttle.end.${sample}.txt

echo "metawrap assembly pipeline done"

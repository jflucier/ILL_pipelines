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

check_software_dependencies () {

    if ! command -v "singularity" &> /dev/null
    then
        echo "##**** singularity could not be found ****"
        echo "## Please make sure the singularity executable is in your PATH variable"
        help_message
        exit 1
    fi

    if ! command -v "repair.sh" &> /dev/null
    then
        echo "##**** BBMap could not be found ****"
        echo "## Please make sure the BBMap executables are in your PATH variable"
        help_message
        exit 1
    fi

}

export EXE_PATH=$(dirname "$0")

# check if singularity and bbmap in path
check_software_dependencies

# initialisation
threads="8"
mem="40G"
sample="false";
out="false";
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
        -o) out=$2; shift 2;;
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

# set assembly options
assembly_programs="--metaspades --megahit"
set_assembly_options $assembly_metaspades $assembly_megahit

echo "analysing sample $sample with metawrap"
echo "fastq1 path: $__fastq_file1"
echo "fastq2 path: $__fastq_file2"

fq1_name=$(basename $fq1)
fq2_name=$(basename $fq2)

echo "upload fastq1 to $tmp/"
cp $fq1 $tmp/$fq1_name
echo "upload fastq2 to $tmp"
cp $fq2 $tmp/$fq2_name

mkdir -p ${tmp}/assembly

echo "sort & reorder paired fastq using bbmap"
repair.sh \
in=$tmp/$fq1_name \
in2=$tmp/$fq2_name \
out=${tmp}/assembly/${sample}_paired_sorted_1.fastq \
out2=${tmp}/assembly/${sample}_paired_sorted_2.fastq

# echo "combining all sample reads for asssembly"
# cat $ASSEMBLY_SAMPLE_F1_PATH_REGEX > ${tmp}/ALL_READS_1.fastq
# cat $ASSEMBLY_SAMPLE_F2_PATH_REGEX > ${tmp}/ALL_READS_2.fastq

echo "metawrap assembly step using ${assembly_programs}"

export SPADES_MEM=$(echo $mem | perl -ne 'chomp($_); chop($_); print $_ . "\n";')
singularity exec --writable-tmpfs -e \
-B ${tmp}:/out \
-B /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/checkm_db:/checkm \
-B /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/NCBI_nt:/NCBI_nt \
-B /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/NCBI_tax:/NCBI_tax \
${EXE_PATH}/../containers/metawrap.1.3.sif \
metaWRAP assembly ${assembly_programs} \
-m $SPADES_MEM -t $threads \
-1 /out/assembly/${sample}_paired_sorted_1.fastq \
-2 /out/assembly/${sample}_paired_sorted_2.fastq \
-o /out/assembly/

echo "copying assembly results back to $out/${sample}/"
mkdir -p $out/
cp -r ${tmp}/assembly/* $out

echo "metawrap assembly pipeline done"

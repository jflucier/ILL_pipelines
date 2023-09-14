#!/bin/bash

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
	echo "Usage: fastq_to_bins.metawrap.sh [-tmp /path/tmp] [-t threads] [-m memory] [--metaspades] [--megahit] -s sample_name -o /path/to/out -fq1 /path/to/fastq1 -fq2 /path/to/fastq2 "
	echo "Options:"

	echo ""
	echo "	-s STR	sample name"
    echo "	-o STR	path to output dir"
    echo "	-tmp STR	path to temp dir (default output_dir/temp)"
    echo "	-t	# of threads (default 8)"
    echo "	-m	memory (default 40G)"
    echo "	-fq1	path to fastq1"
    echo "	-fq2	path to fastq2"
    echo "	--metaspades	use metaspades for assembly (default: false)"
    echo "	--megahit	use megahit for assembly (default: false)"
    echo "	--metabat2	use metabat2 for binning (default: false)"
    echo "	--maxbin2	use maxbin2 for binning (default: false)"
    echo "	--concoct	use concoct for binning (default: false)"
    echo "	--run-checkm	run checkm on bins (default: false)"
    echo "	--refinement_min_compl INT	refinement bin minimum completion percent (default 50)"
    echo "	--refinement_max_cont INT	refinement bin maximum contamination percent (default 10)"
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
assembly_metaspades="false";
assembly_megahit="false";
metabat2="false";
maxbin2="false";
concoct="false"
run_checkm="false"
refinement_min_compl="50";
refinement_max_cont="10";

# load in params
SHORT_OPTS="ht:m:o:s:fq1:fq2:tmp:"
LONG_OPTS='help,metabat2,maxbin2,concoct,run-checkm,metaspades,megahit,refinement_min_compl,refinement_max_cont'

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
    --metabat2) metabat2=true; shift 1;;
    --maxbin2) maxbin2=true; shift 1;;
    --concoct) concoct=true; shift 1;;
    --run-checkm) run_checkm=true; shift 1;;
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
    out=${base_out}
    echo "## Results wil be stored to this path: ${out}"
fi


if [ "$tmp" = "false" ]; then
    tmp=$out/temp/$sample
    mkdir -p $tmp
    echo "## No temp folder provided. Will use: $tmp"
fi

mkdir -p ${tmp}
cd ${tmp}

# set assembly options
assembly_programs="--metaspades --megahit"
set_assembly_options $assembly_metaspades $assembly_megahit

binning_programs="--metabat2 --maxbin2 --concoct --run-checkm"
set_binning_options $metabat2 $maxbin2 $concoct $run_checkm

echo "analysing sample $sample with metawrap"
echo "fastq1 path: $fq1"
echo "fastq2 path: $fq2"
echo "Assembly options: ${assembly_programs}"
echo "Binning options: ${binning_programs}"
echo "Minimum completion percent: $refinement_min_compl"
echo "Maximum contamination percent: $refinement_max_cont"
echo "Threads: $threads"
echo "Memory: $mem"

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
rsync -ah --progress $fq1 $tmp/$fq1_name
echo "upload fastq2 to $tmp"
rsync -ah --progress $fq2 $tmp/$fq2_name
echo "cp singularity container to $tmp"
rsync -ah --progress ${EXE_PATH}/../containers/metawrap.1.3.sif $tmp/

# remove from throttle list
rm ${base_out}/.throttle/throttle.start.${sample}.txt

echo "running BBmap repair.sh"
export BBMAP_MEM=$(echo $mem | perl -ne 'chomp($_); chop($_); print $_ . "\n";')
singularity exec --writable-tmpfs -e \
-B ${tmp}:/out \
$tmp/metawrap.1.3.sif \
repair.sh -Xmx${BBMAP_MEM}g \
overwrite=t \
in=/out/$fq1_name \
in2=/out/$fq2_name \
out=/out/${sample}_paired_sorted_1.fastq \
out2=/out/${sample}_paired_sorted_2.fastq

echo "metawrap assembly step using ${assembly_programs}"
mkdir -p ${tmp}/assembly
export SPADES_MEM=$(echo $mem | perl -ne 'chomp($_); chop($_); print $_ . "\n";')
singularity exec --writable-tmpfs -e \
-W $tmp \
-B ${tmp}:/out \
-B /nfs3_ib/nfs-ip34/fast/def-ilafores/checkm_db:/checkm \
-B /nfs3_ib/nfs-ip34/fast/def-ilafores/NCBI_nt:/NCBI_nt \
-B /nfs3_ib/nfs-ip34/fast/def-ilafores/NCBI_tax:/NCBI_tax \
$tmp/metawrap.1.3.sif \
metaWRAP assembly ${assembly_programs} \
-m $SPADES_MEM -t $threads \
-1 /out/${sample}_paired_sorted_1.fastq \
-2 /out/${sample}_paired_sorted_2.fastq \
-o /out/assembly/

echo "metawrap binning step for sample $sample using $binning_programs"
mkdir -p ${tmp}/binning
export BINNING_MEM=$(echo $mem | perl -ne 'chomp($_); chop($_); print $_ . "\n";')
singularity exec --writable-tmpfs -e \
-W $tmp \
-B ${tmp}:/out \
-B /nfs3_ib/nfs-ip34/fast/def-ilafores/checkm_db:/checkm \
-B /nfs3_ib/nfs-ip34/fast/def-ilafores/NCBI_nt:/NCBI_nt \
-B /nfs3_ib/nfs-ip34/fast/def-ilafores/NCBI_tax:/NCBI_tax \
$tmp/metawrap.1.3.sif \
metaWRAP binning $binning_programs \
-m $BINNING_MEM -t $threads \
-a /out/assembly/final_assembly.fasta \
-o /out/binning/ \
/out/${sample}_paired_sorted_1.fastq /out/${sample}_paired_sorted_2.fastq

echo "metawrap bin refinement for sample $sample using min completion ${refinement_min_compl}% and max contamination ${refinement_max_cont}%"
mkdir -p ${tmp}/bin_refinement/
export BINNING_MEM=$(echo $mem | perl -ne 'chomp($_); chop($_); print $_ . "\n";')
singularity exec --writable-tmpfs -e \
-W $tmp \
-B ${tmp}:/out \
-B /nfs3_ib/nfs-ip34/fast/def-ilafores/checkm_db:/checkm \
-B /nfs3_ib/nfs-ip34/fast/def-ilafores/NCBI_nt:/NCBI_nt \
-B /nfs3_ib/nfs-ip34/fast/def-ilafores/NCBI_tax:/NCBI_tax \
$tmp/metawrap.1.3.sif \
metawrap bin_refinement -t $threads -m $BINNING_MEM --quick \
-c $refinement_min_compl -x $refinement_max_cont \
-o /out/bin_refinement/ \
-A /out/binning/metabat2_bins/ \
-B /out/binning/maxbin2_bins/ \
-C /out/binning/concoct_bins/

sed '1s/$/\tsampID/;2,$s/$/\t'${sample}'/' ${tmp}/bin_refinement/metawrap_${refinement_min_compl}_${refinement_max_cont}_bins.stats > ${tmp}/bin_refinement/${sample}_refined.stats

echo "adding sample name to bin filename"
for bin in ${tmp}/bin_refinement/metawrap_${refinement_min_compl}_${refinement_max_cont}_bins/*.fa
do
  b=$(basename $bin)
  mv $bin ${tmp}/bin_refinement/metawrap_${refinement_min_compl}_${refinement_max_cont}_bins/${sample}.${b}
done

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

mkdir -p ${base_out}/assembly/${sample}
cp -r ${tmp}/assembly/* ${base_out}/assembly/${sample}/

mkdir -p ${base_out}/binning/${sample}
cp -r ${tmp}/binning/* ${base_out}/binning/${sample}/

mkdir -p ${base_out}/bin_refinement/${sample}
cp -r ${tmp}/bin_refinement/* ${base_out}/bin_refinement/${sample}/

# cp done remove from list
rm ${base_out}/.throttle/throttle.end.${sample}.txt

echo "metawrap assembly pipeline done"

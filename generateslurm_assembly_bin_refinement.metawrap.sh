#!/bin/bash

set -e

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


help_message () {
	echo ""
	echo "Usage: generateslurm_denovo_assembly_bin_refinement.metawrap.sh --sample_tsv /path/to/tsv --out /path/to/out [--assembly] [--binning] [--refinement]"
	echo "Options:"

	echo ""
	echo "  --sample_tsv STR	path to sample tsv (5 columns: sample name<tab>fastq1 path<tab>fastq2 path<tab>fastq1 single path<tab>fastq2 single path). Generated in preprocess step."
  echo "	--out STR	path to output dir"
  echo "	--no-metaspades	do not use metaspades for assembly (default: false)"
  echo "	--no-megahit	do not use megahit for assembly (default: false)"
  echo "	--no-metabat2	do not use metabat2 for binning (default: false)"
  echo "	--no-maxbin2	do not use maxbin2 for binning (default: false)"
  echo "	--no-concoct	do not use concoct for binning (default: false)"
  echo "	--no-checkm	do not run checkm for binning (default: false)"
  echo "	--refinement_min_compl INT	refinement bin minimum completion percent (default 50)"
  echo "	--refinement_max_cont INT	refinement bin maximum contamination percent (default 10)"

  echo ""
  echo "Slurm options:"
  echo "	--slurm_alloc STR	slurm allocation (default def-ilafores)"
  echo "	--slurm_log STR	slurm log file output directory (default to output_dir/logs)"
  echo "	--slurm_email \"your@email.com\"	Slurm email setting"
  echo "	--slurm_walltime STR	slurm requested walltime (default 24:00:00)"
  echo "	--slurm_threads INT	slurm requested number of threads (default 48)"
  echo "	--slurm_mem STR	slurm requested memory (default 251G)"

  echo ""
  echo "  -h --help	Display help"

	echo "";
}


# load and valdiate env
export EXE_PATH=$(dirname "$0")

# initialisation
alloc="def-ilafores"
email="false"
walltime="24:00:00"
threads="24"
mem="30G"
log="false"

sample_tsv="false";
out="false";

assembly_metaspades="true";
assembly_megahit="true";

binning_metabat2="true";
binning_maxbin2="true";
binning_concoct="true";
binning_run_checkm="true";

refinement_min_compl="50"
refinement_max_cont="10"

# load in params
SHORT_OPTS="h"
LONG_OPTS='help,slurm_alloc,slurm_log,slurm_email,slurm_walltime,slurm_threads,slurm_mem,\
sample_tsv,out,\
no-metaspades,no-megahit,\
no-metabat2,no-maxbin2,no-concoct,no-checkm,\
refinement_min_compl,refinement_max_cont'

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
    --slurm_alloc) alloc=$2; shift 2;;
    --slurm_log) log=$2; shift 2;;
    --slurm_email) email=$2; shift 2;;
    --slurm_walltime) walltime=$2; shift 2;;
    --slurm_threads) threads=$2; shift 2;;
    --slurm_mem) mem=$2; shift 2;;
    --sample_tsv) sample_tsv=$2; shift 2;;
    --out) out=$2; shift 2;;
    --no-metaspades) assembly_metaspades=false; shift 1;;
		--no-megahit) assembly_megahit=false; shift 1;;
    --no-metabat2) binning_metabat2=false; shift 1;;
    --no-maxbin2) binning_maxbin2=false; shift 1;;
    --no-concoct) binning_concoct=false; shift 1;;
    --no-checkm) binning_run_checkm=false; shift 1;;
    --refinement_min_compl) refinement_min_compl=$2; shift 2;;
    --refinement_max_cont) refinement_max_cont=$2; shift 2;;
    --) help_message; exit 1; shift; break ;;
		*) break;;
	esac
done

# check if all parameters are entered
if [ "$sample_tsv" = "false" ]; then
    echo "Please provide a sample list file."
    help_message; exit 1
elif [[ ! -f $sample_tsv ]]
then
    echo "Sample file ${sample_tsv} does not exist!"
else
    echo "## Will use sample file: $sample_tsv"
fi

if [ "$out" = "false" ]; then
    echo "Please provide an output path"
    help_message; exit 1
elif [[ ! -d "$out" ]]; then
    echo "## Output path $out doesnt exist. Will create it!"
    rm -fr $out
    mkdir -p $out
fi

echo "## Results wil be stored to this path: $out"

if [ "$log" = "false" ]; then
    log=$out/logs
    echo "## Slurm output path not specified, will output logs in: $log"
else
    echo "## Will output logs in: $log"
fi

mkdir -p $log

assembly_programs="--metaspades --megahit"
set_assembly_options $assembly_metaspades $assembly_megahit

# set binning options
binning_programs="--metabat2 --maxbin2 --concoct --run-checkm"
set_binning_options $binning_metabat2 $binning_maxbin2 $binning_concoct $binning_run_checkm

echo "# Bin minimum % completion: ${refinement_min_compl}%"
echo "# Bin maximum % contamination: ${refinement_max_cont}%"

echo "Cleaning throtthling dir"
rm ${out}/.throttle/*

echo "outputting slurm script to $out/assembly_bin_refinement.metawrap.slurm.sh"

echo '#!/bin/bash' > $out/assembly_bin_refinement.metawrap.slurm.sh
echo '
#SBATCH --mail-type=END,FAIL
#SBATCH -D '${out}'
#SBATCH -o '${log}'/assembly_bin_refinement-%A_%a.slurm.out
#SBATCH --time='${walltime}'
#SBATCH --mem='${mem}'
#SBATCH -n '${threads}'
#SBATCH -N 1
#SBATCH -A '${alloc}'
#SBATCH -J assembly_bin_refinement
' >> $out/assembly_bin_refinement.metawrap.slurm.sh

if [ "$email" != "false" ]; then
echo '
#SBATCH --mail-user='${email}'
' >> $out/assembly_bin_refinement.metawrap.slurm.sh
fi

echo '

echo "loading env"
module load StdEnv/2020 apptainer/1.1.5

export __sample_line=$(cat '${sample_tsv}' | awk "NR==$SLURM_ARRAY_TASK_ID")
export __sample=$(echo -e "$__sample_line" | cut -f1)
export __fastq_file1=$(echo -e "$__sample_line" | cut -f2)
export __fastq_file2=$(echo -e "$__sample_line" | cut -f3)

echo "running fastq to bins on $__sample"
bash '${EXE_PATH}'/scripts/fastq_to_bins.metawrap.sh \
-o '${out}'/ \
-tmp $SLURM_TMPDIR \
-t '${threads}' -m '${mem}' \
-s $__sample \
-fq1 $__fastq_file1 -fq2 $__fastq_file2 \
'$assembly_programs' \
'$binning_programs' \
--refinement_min_compl '${refinement_min_compl}' --refinement_max_cont '${refinement_max_cont}'

echo "done metawrap pipeline on $__sample"

' >> $out/assembly_bin_refinement.metawrap.slurm.sh

echo "To submit to slurm, execute the following command:"
read sample_nbr f r <<< $(wc -l ${sample_tsv})
echo "sbatch --array=1-$sample_nbr $out/assembly_bin_refinement.metawrap.slurm.sh"


#if [ "$assembly_step" = "true" ]
#then
#    echo '
#    echo "running assembly on $__sample"
#    bash '${EXE_PATH}'/scripts/assembly.metawrap.sh \
#    -o '${out}'/ \
#    -tmp $SLURM_TMPDIR \
#    -t '${threads}' -m '${mem}' \
#    -s $__sample -fq1 $__fastq_file1 -fq2 $__fastq_file2 \
#    '$assembly_programs'
#
#    echo "done assembly on $__sample"
#    ' >> $out/assembly_bin_refinement.metawrap.slurm.sh
#fi
#
#if [ "$binning_step" = "true" ]
#then
#    echo '
#    echo "running binning on $__sample"
#    bash '${EXE_PATH}'/scripts/binning.metawrap.sh \
#    -o '${out}'/ \
#    -tmp $SLURM_TMPDIR \
#    -t '${threads}' -m '${mem}' \
#    -s $__sample \
#    -fq1 '${out}'/assembly/${__sample}/${__sample}_paired_sorted_1.fastq \
#    -fq2 '${out}'/assembly/${__sample}/${__sample}_paired_sorted_2.fastq \
#    -a '${out}'/assembly/${__sample}/final_assembly.fasta \
#    '$binning_programs'
#
#    echo "done binning on $__sample"
#    ' >> $out/assembly_bin_refinement.metawrap.slurm.sh
#fi
#
#if [ "$refinement_step" = "true" ]
#then
#    echo '
#    echo "running bin refinement on $__sample"
#    bash '${EXE_PATH}'/scripts/bin_refinement.metawrap.sh \
#    -o '${out}'/ \
#    -tmp $SLURM_TMPDIR \
#    -t '${threads}' -m '${mem}' \
#    -s $__sample \
#    --metabat2_bins '${out}'/binning/${__sample}/metabat2_bins \
#    --maxbin2_bins '${out}'/binning/${__sample}/maxbin2_bins \
#    --concoct_bins '${out}'/binning/${__sample}/concoct_bins \
#    --refinement_min_compl '${refinement_min_compl}' \
#    --refinement_max_cont '${refinement_max_cont}'
#
#    echo "done bin refinement on $__sample"
#    ' >> $out/assembly_bin_refinement.metawrap.slurm.sh
#fi

#!/bin/bash

set -e

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
	echo "	--sample_tsv STR	path to sample tsv (3 columns: sample name<tab>fastq1 path<tab>fastq2 path)"
    echo "	--out STR	path to output dir"
    echo "	--assembly	perform assembly"
    echo "	--binning	perform binning step"
    echo "	--refinement	perform refinement step"

	echo ""
    echo "Metawrap options:"
    echo "	--metaspades	use metaspades for assembly (default: true)"
    echo "	--megahit	use megahit for assembly (default: true)"
    echo "	--metabat2	use metabat2 for binning (default: true)"
    echo "	--maxbin2	use maxbin2 for binning (default: true)"
    echo "	--concoct	use concoct for binning (default: true)"
    echo "	--run-checkm	run checkm for binning (default: true)"
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

# check if singularity and bbmap in path
check_software_dependencies

# initialisation
alloc="def-ilafores"
email="false"
walltime="24:00:00"
threads="48"
mem="251G"
log="false"

sample_tsv="false";
out="false";

assembly_step="false";
assembly_metaspades="false";
assembly_megahit="false";

binning_step="false";
binning_metabat2="false";
binning_maxbin2="false";
binning_concoct="false";
binning_run_checkm="false";

refinement_step="false";
refinement_min_compl="50"
refinement_max_cont="10"

# load in params
SHORT_OPTS="h"
LONG_OPTS='help,slurm_alloc,slurm_log,slurm_email,slurm_walltime,slurm_threads,slurm_mem,\
sample_tsv,out,\
assembly,metaspades,megahit,
binning,metabat2,maxbin2,concoct\
refinement,refinement_min_compl,refinement_max_cont'

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
		--assembly) assembly_step=true; shift 1;;
        --metaspades) assembly_metaspades=true; shift 1;;
		--megahit) assembly_megahit=true; shift 1;;
		--binning) binning_step=true; shift 1;;
        --metabat2) binning_metabat2=true; shift 1;;
        --maxbin2) binning_maxbin2=true; shift 1;;
        --concoct) binning_concoct=true; shift 1;;
        --run-checkm) binning_run_checkm=true; shift 1;;
        --refinement) refinement_step=true; shift 1;;
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

if [ "$assembly_step" = "false" ] && [ "$binning_step" = "false" ] && [ "$refinement_step" = "false" ]; then
    echo "At least one analysis step must be activated (assembly AND/OR binning AND/OR refinement)."
    help_message; exit 1
fi

# set assembly options
if [ "$assembly_step" = "true" ]
then
    echo "## Assembly step is activated"
    assembly_programs="--metaspades --megahit"
    set_assembly_options $assembly_metaspades $assembly_megahit
fi

# set binning options
if [ "$binning_step" = "true" ]
then
    echo "## Binning step is activated"
    binning_programs="--metabat2 --maxbin2 --concoct --run-checkm"
    set_binning_options $binning_metabat2 $binning_maxbin2 $binning_concoct $binning_run_checkm
fi

if [ "$refinement_step" = "true" ]
then
    echo "## Bin refinement step is activated"
    echo "# Bin minimum % completion: ${refinement_min_compl}%"
    echo "# Bin maximum % contamination: ${refinement_max_cont}%"
fi




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

newgrp def-ilafores
echo "loading env"
export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6
module use $MUGQIC_INSTALL_HOME/modulefiles
module load StdEnv/2020 gcc/9 python/3.7.9 java/14.0.2 singularity/3.7 mugqic/BBMap/38.90


export __sample_line=$(cat '${sample_tsv}' | awk "NR==$SLURM_ARRAY_TASK_ID")
export __sample=$(echo -e "$__sample_line" | cut -f1)
export __fastq_file1=$(echo -e "$__sample_line" | cut -f2)
export __fastq_file2=$(echo -e "$__sample_line" | cut -f3)

' >> $out/assembly_bin_refinement.metawrap.slurm.sh

if [ "$assembly_step" = "true" ]
then
    echo '
    echo "running assembly on $__sample"
    bash '${EXE_PATH}'/scripts/assembly.metawrap.sh \
    -o '${out}'/assembly/'$__sample' \
    -tmp $SLURM_TMPDIR \
    -t '${threads}' -m '${mem}' \
    -s $__sample -fq1 $__fastq_file1 -fq2 $__fastq_file2 \
    '$assembly_programs'

    echo "done assembly on $__sample"
    ' >> $out/assembly_bin_refinement.metawrap.slurm.sh
fi

if [ "$binning_step" = "true" ]
then
    echo '
    echo "running binning on $__sample"
    bash '${EXE_PATH}'/scripts/binning.metawrap.sh \
    -o '${out}'/binning/${__sample} \
    -tmp $SLURM_TMPDIR \
    -t '${threads}' -m '${mem}' \
    -s $__sample \
    -fq1 '${out}'/assembly/${__sample}/${__sample}_paired_sorted_1.fastq \
    -fq2 '${out}'/assembly/${__sample}/${__sample}_paired_sorted_2.fastq \
    -a '${out}'/assembly/${__sample}/final_assembly.fasta
    '$binning_programs'

    echo "done binning on $__sample"
    ' >> $out/assembly_bin_refinement.metawrap.slurm.sh
fi

if [ "$refinement_step" = "true" ]
then
    echo '
    echo "running bin refinement on $__sample"
    bash '${EXE_PATH}'/scripts/bin_refinement.metawrap.sh \
    -o '${out}'/refinement/${__sample} \
    -tmp $SLURM_TMPDIR \
    -t '${threads}' -m '${mem}' \
    -s $__sample \
    --metabat2_bins '${out}'/binning/${__sample}/metabat2_bins \
    --maxbin2_bins '${out}'/binning/${__sample}/maxbin2_bins \
    --concoct_bins '${out}'/binning/${__sample}/concoct_bins \
    --refinement_min_compl '${refinement_min_compl}'
    --refinement_max_cont '${refinement_max_cont}'

    echo "done bin refinement on $__sample"
    ' >> $out/assembly_bin_refinement.metawrap.slurm.sh
fi


echo "To submit to slurm, execute the following command:"
read sample_nbr f r <<< $(wc -l ${sample_tsv})
echo "sbatch --array=1-$sample_nbr $out/assembly_bin_refinement.metawrap.slurm.sh"

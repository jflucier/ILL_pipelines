#!/bin/bash

set -e

help_message () {
	echo ""
	echo "Usage: generateslurm_quantify_bins.sh -sample_tsv /path/to/samplesheet -drep /path/to/drep/genome -o /path/to/out --bowtie_index_name idx_nbame"
	echo "Options:"

	echo ""
	echo "	-sample_tsv	A 3 column tsv of samples. Columns should be sample_name<tab>/path/to/fastq1<tab>/path/to/fastq2. No headers! HINT: preprocess step generates this file"
  echo "	-drep STR	dereplicated genome path (drep output directory). See dereplicate_bins.dRep.sh for more information."
  echo "	-o STR	path to output dir"

  echo ""
  echo "Slurm options:"
  echo "	--slurm_alloc STR	slurm allocation (default def-ilafores)"
  echo "	--slurm_log STR	slurm log file output directory (default to output_dir/logs)"
  echo "	--slurm_email \"your@email.com\"	Slurm email setting"
  echo "	--slurm_walltime STR	slurm requested walltime (default 24:00:00)"
  echo "	--slurm_threads INT	slurm requested number of threads (default 24)"
  echo "	--slurm_mem STR	slurm requested memory (default 31G)"

  echo ""
  echo "  -h --help	Display help"

	echo "";
}


export EXE_PATH=$(dirname "$0")

# initialisation
alloc="def-ilafores"
email="false"
walltime="24:00:00"
threads="24"
mem="31G"
log="false"

drep="false"
out="false"
sample_tsv="false"

SHORT_OPTS="ht:drep:o:sample_tsv:"
LONG_OPTS='help,slurm_alloc,slurm_log,slurm_email,slurm_walltime,slurm_threads,slurm_mem'

OPTS=$(getopt -o $SHORT_OPTS --long $LONG_OPTS -- "$@")
# make sure the params are entered correctly
if [ $? -ne 0 ];
then
    help_message;
    exit 1;
fi

while true; do
    # echo "$1 -- $2"
	case "$1" in
		-h | --help) help_message; exit 1; shift 1;;
    --slurm_alloc) alloc=$2; shift 2;;
    --slurm_log) log=$2; shift 2;;
    --slurm_email) email=$2; shift 2;;
    --slurm_walltime) walltime=$2; shift 2;;
    --slurm_threads) threads=$2; shift 2;;
    --slurm_mem) mem=$2; shift 2;;
		-o) out=$2; shift 2;;
		-drep) drep=$2; shift 2;;
    -sample_tsv) sample_tsv=$2; shift 2;;
    --) help_message; exit 1; shift; break ;;
		*) break;;
	esac
done

echo "## Quantify parameters:"

if [ "$drep" = "false" ]; then
    echo "Please provide a drep output output bin path (/path/to/drep/out/dereplicated_genomes)"
    help_message; exit 1
else
    echo "## Drep path: $sample_tsv"
fi

if [ "$sample_tsv" = "false" ]; then
    echo "Please provide a samplesheet path. This sample sheet is generated by preprocess step. TSV columns should be sample_name<tab>/path/to/fastq1<tab>/path/to/fastq2"
    help_message; exit 1
else
    echo "## Samplesheet path: $sample_tsv"
fi

if [ "$out" = "false" ]; then
    echo "Please provide an output path"
    help_message; exit 1
else
    mkdir -p $out
    echo "## Results wil be stored to this path: $out/"
fi

if [ "$log" = "false" ]; then
    log=$out/logs
    echo "## Slurm output path not specified, will output logs in: $log"
else
    echo "## Will output logs in: $log"
fi

mkdir -p $log

echo "## Number of threads: $threads"


echo "outputting annotate slurm script to $out/submit_quantify.slurm.sh"
echo '#!/bin/bash' > $out/submit_quantify.slurm.sh
echo '
#SBATCH --mail-type=END,FAIL
#SBATCH -D '${out}'
#SBATCH -o '${out}'/logs/qunatify-%A.slurm.out
#SBATCH --time='${walltime}'
#SBATCH --mem='${mem}'
#SBATCH -N 1
#SBATCH -n '${threads}'
#SBATCH -A '${alloc}'
#SBATCH -J annotate
' >> $out/submit_quantify.slurm.sh

if [ "$email" != "false" ]; then
echo '
#SBATCH --mail-user='${email}'
' >> $out/submit_quantify.slurm.sh
fi

echo '
echo "loading env"
module load StdEnv/2020 apptainer/1.1.5

if [ -z ${SLURM_TMPDIR+x} ]
then
  echo "SLURM_TMPDIR is unset. Not running on compute node"
  bash '${EXE_PATH}'/scripts/quantify_bins.salmon.sh \
  -t '${threads}' \
  -drep '$drep' \
  -sample_tsv '$sample_tsv' \
  -o '${out}'
else
  echo "SLURM_TMPDIR is set to $SLURM_TMPDIR. Running on a compute node!"
  bash '${EXE_PATH}'/scripts/quantify_bins.salmon.sh  \
  -t '${threads}' \
  -drep '${drep}' \
  -sample_tsv '${sample_tsv}' \
  -o '${out}' \
  -tmp $SLURM_TMPDIR
fi

' >> $out/submit_quantify.slurm.sh


echo "To run LOCALLY, execute the following command:"
echo "bash ${out}/submit_quantify.slurm.sh"
echo "---- OR -----"
echo "To submit to slurm, execute the following command:"
echo "sbatch ${out}/submit_quantify.slurm.sh"


echo "done!"

#!/bin/bash

set -e

help_message () {
	echo ""
	echo "Usage: generateslurm_annotate_bins.sh --kreports 'kraken_report_regex' --out /path/to/out --bowtie_index_name idx_nbame"
	echo "Options:"

	echo ""
  echo "	-o STR	path to output dir"
  echo "	-drep dereplicated genome path (drep output directory). See dereplicate_bins.dRep.sh for more information."
	echo "	-db	MicrobeAnnotator DB path (default: /net/nfs-ip34/fast/def-ilafores/MicrobeAnnotator_DB)."

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
db="/net/nfs-ip34/fast/def-ilafores/MicrobeAnnotator_DB"

SHORT_OPTS="ht:drep:o:db:"
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
    -db) db=$2; shift 2;;
    --) help_message; exit 1; shift; break ;;
		*) break;;
	esac
done

if [ "$drep" = "false" ]; then
    echo "Please provide a drep output output bin path (/path/to/drep/out/dereplicated_genomes)"
    help_message; exit 1
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

echo "## Annotate parameters:"
echo "## drep path: $drep"
echo "## Ouptut path: $out"
echo "## MicrobeAnnotator DB path: $db"
echo "## Number of threads: $threads"


echo "outputting annotate slurm script to $out/submit_annotate.slurm.sh"
echo '#!/bin/bash' > $out/submit_annotate.slurm.sh
echo '
#SBATCH --mail-type=END,FAIL
#SBATCH -D '${out}'
#SBATCH -o '${out}'/logs/drep-%A.slurm.out
#SBATCH --time='${walltime}'
#SBATCH --mem='${mem}'
#SBATCH -N 1
#SBATCH -n '${threads}'
#SBATCH -A '${alloc}'
#SBATCH -J annotate
' >> $out/submit_annotate.slurm.sh

if [ "$email" != "false" ]; then
echo '
#SBATCH --mail-user='${email}'
' >> $out/submit_annotate.slurm.sh
fi

echo '
newgrp def-ilafores
module load StdEnv/2020 apptainer/1.1.5

bash '${EXE_PATH}'/scripts/annotate_bins.dRep.sh \
-t '${threads}' \
-drep '$drep' \
-db '$db' \
-o '${out}' \
-tmp $SLURM_TMPDIR

' >> $out/submit_annotate.slurm.sh

echo "To submit to slurm, execute the following command:"
echo "sbatch ${out}/submit_annotate.slurm.sh"

echo "done!"

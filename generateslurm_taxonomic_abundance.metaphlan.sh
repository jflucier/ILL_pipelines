#!/bin/bash -l

set -e

help_message () {
	echo ""
	echo "Usage: generateslurm_taxonomic_abundance.metaphlan.sh --sample_tsv /path/to/tsv --out /path/to/out [--db /path/to/metaphlan/db]"
	echo "Options:"

	echo ""
	echo "   --sample_tsv STR	path to sample tsv (5 columns: sample name<tab>fastq1 path<tab>fastq2 path<tab>fastq1 single path<tab>fastq2 single path). Generated in preprocess step."
  echo "   --out STR	path to output dir"
  echo "	 --db	metaphlan db path (default /cvmfs/datahub.genap.ca/vhost34/def-ilafores/metaphlan4_db/mpa_vOct22_CHOCOPhlAnSGB_202212)"

  echo ""
  echo "Slurm options:"
  echo "   --slurm_alloc STR	slurm allocation (default def-ilafores)"
  echo "   --slurm_log STR	slurm log file output directory (default to output_dir/logs)"
  echo "   --slurm_email \"your@email.com\"	Slurm email setting"
  echo "   --slurm_walltime STR	slurm requested walltime (default 24:00:00)"
  echo "   --slurm_threads INT	slurm requested number of threads (default 4)"
  echo "   --slurm_mem STR	slurm requested memory (default 25G)"

  echo ""
  echo "   -h --help	Display help"

	echo "";
}

export EXE_PATH=$(dirname "$0")

# initialisation
alloc="def-ilafores"
email="false"
walltime="24:00:00"
threads="4"
mem="25G"
log="false"

sample_tsv="false";
out="false";
db="/cvmfs/datahub.genap.ca/vhost34/def-ilafores/metaphlan4_db/mpa_vOct22_CHOCOPhlAnSGB_202212"

# load in params
SHORT_OPTS="h"
LONG_OPTS='help,slurm_alloc,slurm_log,slurm_email,slurm_walltime,slurm_threads,slurm_mem,\
sample_tsv,out,db'

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
        --slurm_alloc) alloc=$2; shift 2;;
        --slurm_log) log=$2; shift 2;;
        --slurm_email) email=$2; shift 2;;
        --slurm_walltime) walltime=$2; shift 2;;
        --slurm_threads) threads=$2; shift 2;;
        --slurm_mem) mem=$2; shift 2;;
        --sample_tsv) sample_tsv=$2; shift 2;;
        --out) out=$2; shift 2;;
		    --db) db=$2; shift 2;;
        --) help_message; exit 1; shift; break ;;
		*) break;;
	esac
done

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
fi

mkdir -p $out

echo "## Results wil be stored to this path: $out"

if [ "$log" = "false" ]; then
    log=$out/logs
    echo "## Slurm output path not specified, will output logs in: $log"
else
    echo "## Will output logs in: $log"
fi

mkdir -p $log

echo "outputting sample taxonomic profile slurm script to ${out}/metaphlan.slurm.sh"
echo '#!/bin/bash -l' > ${out}/metaphlan.slurm.sh
echo '
#SBATCH --mail-type=END,FAIL
#SBATCH -D '${out}'
#SBATCH -o '${log}'/metaphlan-%A_%a.slurm.out
#SBATCH --time='${walltime}'
#SBATCH --mem='${mem}'
#SBATCH -N 1
#SBATCH -n '${threads}'
#SBATCH -A '${alloc}'
#SBATCH -J metaphlan
' >> ${out}/metaphlan.slurm.sh

if [ "$email" != "false" ]; then
echo '
#SBATCH --mail-user='${email}'
' >> ${out}/metaphlan.slurm.sh
fi

echo '
echo "loading env"
module load StdEnv/2020 apptainer/1.1.5

export __sample_line=$(cat '${sample_tsv}' | awk "NR==$SLURM_ARRAY_TASK_ID")
export __sample=$(echo -e "$__sample_line" | cut -f1)
export __fastq_file1=$(echo -e "$__sample_line" | cut -f2)
export __fastq_file2=$(echo -e "$__sample_line" | cut -f3)
export __fastq_file1_single=$(echo -e "$__sample_line" | cut -f4)
export __fastq_file2_single=$(echo -e "$__sample_line" | cut -f5)

bash -l '${EXE_PATH}'/scripts/taxonomic_abundance.metaphlan.sh \
-o '${out}'/ \
-tmp $SLURM_TMPDIR \
-t '${threads}' \
-s $__sample \
-fq1 $__fastq_file1 \
-fq2 $__fastq_file2 \
-fq1_single $__fastq_file1_single \
-fq2_single $__fastq_file2_single \
-db '$db'

' >> ${out}/metaphlan.slurm.sh

echo "To submit to slurm, execute the following command:"
read sample_nbr f <<< $(wc -l ${sample_tsv})
echo "sbatch --array=1-$sample_nbr ${out}/metaphlan.slurm.sh"

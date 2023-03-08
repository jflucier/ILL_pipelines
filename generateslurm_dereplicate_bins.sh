#!/bin/bash

set -e

help_message () {
	echo ""
	echo "Usage: generateslurm_dereplicate_bins.sh [-a {fastANI,ANIn,gANI,ANImf,goANI}] [...] --bins_tsv /ath/to/tsv -o /path/to/out "
	echo "Options:"

	echo ""
	#echo "	-bins_tsv	A 2 column tsv of fasta bins for all samples. Columns should be sample_name<tab>/path/to/fa. No headers!"
		echo "	-bin_path_regex	A regex path to bins, i.e. /path/to/bin/*/*.fa"
    echo "	-o STR	path to output dir"
	echo "	-a	algorithm {fastANI,ANIn,gANI,ANImf,goANI} (default: ANImf). See dRep documentation for more information."
    echo "	-p_ani	ANI threshold to form primary (MASH) clusters (default: 0.95)"
    echo "	-s_ani	ANI threshold to form secondary clusters (default: 0.99)"
    echo "	-cov	Minmum level of overlap between genomes when doing secondary comparisons (default: 0.1)"
    echo "	-comp	Minimum genome completeness (default: 75)"
	echo "	-con	Maximum genome contamination (default: 25)"

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


export EXE_PATH=$(dirname "$0")

# initialisation
alloc="def-ilafores"
email="false"
walltime="24:00:00"
threads="48"
mem="251G"
log="false"

bin_path_regex="false"
out="false"
algo="ANImf"
p_ani="0.95"
s_ani="0.99"
cov="0.1"
comp="75"
con="25"

SHORT_OPTS="ht:bin_path_regex:o:a:p_ani:s_ani:cov:comp:con:"
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
		-bin_path_regex) bin_path_regex=$2; shift 2;;
        -a) algo=$2; shift 2;;
        -p_ani) p_ani=$2; shift 2;;
        -s_ani) s_ani=$2; shift 2;;
		-cov) cov=$2; shift 2;;
        -comp) comp=$2; shift 2;;
        -con) con=$2; shift 2;;
        --) help_message; exit 1; shift; break ;;
		*) break;;
	esac
done

if [ "$bin_path_regex" = "false" ]; then
    echo "Please provide a bin regex path, i.e. /path/to/fa/*.fa."
    help_message; exit 1
else
	echo "## Genome bins path: '$bin_path_regex'"
	l=$(ls $bin_path_regex | wc -l)
	echo "## Number of bins: $l"
	echo "## List of bins: "
	ls -1 $bin_path_regex
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

echo "## dRep parameters:"
echo "## Algorithm for secondary clustering comparisons: $algo"
echo "## ANI threshold to form primary (MASH) clusters: $p_ani"
echo "## ANI threshold to form secondary clusters: $s_ani"
echo "## Minmum level of overlap between genomes: $cov"
echo "## Minimum genome completeness: $comp"
echo "## Maximum genome contamination: $con"
echo "## Number of threads: $threads"


echo "outputting dRep slurm script to $out/submit_dRep.slurm.sh"
echo '#!/bin/bash' > $out/submit_dRep.slurm.sh
echo '
#SBATCH --mail-type=END,FAIL
#SBATCH -D '${out}'
#SBATCH -o '${out}'/logs/drep-%A.slurm.out
#SBATCH --time='${walltime}'
#SBATCH --mem='${mem}'
#SBATCH -N 1
#SBATCH -n '${threads}'
#SBATCH -A '${alloc}'
#SBATCH -J dRep
' >> $out/submit_dRep.slurm.sh

if [ "$email" != "false" ]; then
echo '
#SBATCH --mail-user='${email}'
' >> $out/submit_dRep.slurm.sh
fi

echo '
echo "loading env"
module load StdEnv/2020 apptainer/1.1.5

bash '${EXE_PATH}'/scripts/dereplicate_bins.dRep.sh \
-t '${threads}' -a '$algo' -p_ani '$p_ani' -s_ani '$s_ani' -cov '$cov' -comp '$comp' -con '$con' \
-bin_path_regex "'$bin_path_regex'" \
-o '${out}' \
-tmp $SLURM_TMPDIR

' >> $out/submit_dRep.slurm.sh

echo "To submit to slurm, execute the following command:"
echo "sbatch ${out}/submit_dRep.slurm.sh"

echo "done!"

#!/bin/bash

set -e

help_message () {
	echo ""
	echo "Usage: generateslurm_taxonomic_profile.allsamples.sh --kreports 'kraken_report_regex' --out /path/to/out --bowtie_index_name idx_nbame"
	echo "Options:"

	echo ""
    echo "	--kreports STR	base path regex to retrieve species level kraken reports (i.e.: "$PWD"/taxonomic_profile/*/*_bracken/*_bracken_S.kreport)."
    echo "	--out STR	path to output dir"
    echo "	--bowtie_index_name  name of the bowtie index that will be generated"
    echo "	--chocophlan_db	path to the full chocoplan db (default: /net/nfs-ip34/fast/def-ilafores/humann_dbs/chocophlan)"

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

kreports='false'
out="false";
bowtie_idx_name="false";
choco_db="/net/nfs-ip34/fast/def-ilafores/humann_dbs/chocophlan"

SHORT_OPTS="h"
LONG_OPTS='help,slurm_alloc,slurm_log,slurm_email,slurm_walltime,slurm_threads,slurm_mem,kreports,out,bowtie_index_name,chocophlan_db'

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
        --kreports) kreports=$2; shift 2;;
        --out) out=$2; shift 2;;
		--bowtie_index_name) bowtie_idx_name=$2; shift 2;;
        --chocophlan_db) choco_db=$2; shift 2;;
        --) help_message; exit 1; shift; break ;;
		*) break;;
	esac
done

if [ "$kreports" = "false" ]; then
    echo "Please provide a species taxonomic level kraken report regex."
    help_message; exit 1
fi

kreport_files=$(ls $kreports | wc -l)
if [ $kreport_files -eq 0 ]; then
    echo "Provided species kreport regex $kreports returned 0 report files. Please validate your regex."
    help_message; exit 1
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

if [ "$bowtie_idx_name" = "false" ]; then
    echo "Please provide a bowtie index name"
    help_message; exit 1
else
    echo "## Bowtie index will be generated in this path: $out/${bowtie_idx_name}"
fi

echo "outputting all sample taxonomic profile slurm script to $out/taxonomic_profile.allsamples.slurm.sh"
echo '#!/bin/bash' > $out/taxonomic_profile.allsamples.slurm.sh
echo '
#SBATCH --mail-type=END,FAIL
#SBATCH -D '${out}'
#SBATCH -o '${out}'/logs/taxonomic_profile_all-%A.slurm.out
#SBATCH --time='${walltime}'
#SBATCH --mem='${mem}'
#SBATCH -N 1
#SBATCH -n '${threads}'
#SBATCH -A '${alloc}'
#SBATCH -J all_taxonomic_profile
' >> ${out}/taxonomic_profile.allsamples.slurm.sh

if [ "$email" != "false" ]; then
echo '
#SBATCH --mail-user='${email}'
' >> ${out}/taxonomic_profile.allsamples.slurm.sh
fi

echo '
echo "loading env"
module load StdEnv/2020 apptainer/1.1.5

bash '${EXE_PATH}'/scripts/taxonomic_profile.allsamples.sh \
--kreports "'$kreports'" \
--out '${out}' \
--tmp $SLURM_TMPDIR \
--threads '${threads}' \
--bowtie_index_name '$bowtie_idx_name' \
--chocophlan_db '$choco_db'

# clean tmp dir
rm -fr $SLURM_TMPDIR/*

__all_taxas=(
    "D:domains"
    "P:phylums"
    "C:classes"
    "O:orders"
    "F:families"
    "G:genuses"
    "S:species"
)

basepath=$(echo "'$kreports'" | perl -ne "
  my @t = split('"'"'/'"'"',$_);
  pop @t;
  print join('"'"'/'"'"',@t);
")

for taxa_str in "${__all_taxas[@]}"
do
  taxa_oneletter=${taxa_str%%:*}
  taxa_name=${taxa_str#*:}

  report_path="${basepath}/*_bracken_${taxa_oneletter}.kreport"

  echo "running tax table for $taxa_oneletter using report regex $report_path"
  bash '${EXE_PATH}'/scripts/taxonomic_table.allsamples.sh \
  --kreports "$report_path" \
  --out '${out}' \
  --tmp $SLURM_TMPDIR \
  --taxa_code $taxa_oneletter
done


' >> ${out}/taxonomic_profile.allsamples.slurm.sh

echo ""
echo ""
echo "To run, execute the following commands:"
echo "export SLURM_TMPDIR=/path/to/your/temp"
echo "bash ${out}/taxonomic_profile.allsamples.slurm.sh"
echo "--- OR ---"
echo "To submit to slurm, execute the following command:"
echo "sbatch ${out}/taxonomic_profile.allsamples.slurm.sh"

echo "done!"

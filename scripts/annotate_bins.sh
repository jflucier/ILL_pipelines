#!/bin/bash

set -e

help_message () {
	echo ""
	echo "Usage: annotate_bins.sh [-tmp /path/tmp] [-t threads] [-ma_db /path/to/microannotatordb] [-gtdb_db /path/to/GTDB] -drep /path/to/drep/dereplicated_genomes -o /path/to/out "
	echo "Options:"

	echo ""
	echo "	-tmp STR	path to temp dir (default output_dir/temp)"
  echo "	-o STR	path to output dir"
	echo "	-t	# of threads (default 24)"
  echo "	-drep dereplicated genome path (drep output directory). See dereplicate_bins.dRep.sh for more information."
	echo "	-ma_db	MicrobeAnnotator DB path (default: /cvmfs/datahub.genap.ca/vhost34/def-ilafores/MicrobeAnnotator_DB)."
	echo "	-gtdb_db	GTDB DB path (default: /cvmfs/datahub.genap.ca/vhost34/def-ilafores/GTDB/release207_v2)."

  echo ""
  echo "  -h --help	Display help"

	echo "";
}

export EXE_PATH=$(dirname "$0")

# initialisation
threads="24"
out="false"
drep="false"
ma_db="/cvmfs/datahub.genap.ca/vhost34/def-ilafores/MicrobeAnnotator_DB"
gtdb_db="/cvmfs/datahub.genap.ca/vhost34/def-ilafores/GTDB/release207_v2"
tmp="false"


# load in params
SHORT_OPTS="ht:o:drep:ma_db:gtdb_db:tmp:"
LONG_OPTS='help'

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
    -o) out=$2; shift 2;;
		-drep) drep=$2; shift 2;;
    -ma_db) ma_db=$2; shift 2;;
    -gtdb_db) gtdb_db=$2; shift 2;;
    -tmp) tmp=$2; shift 2;;
    --) help_message; exit 1; shift; break ;;
		*) break;;
	esac
done

if [ "$out" = "false" ]; then
    echo "Please provide an output path"
    help_message; exit 1
else
    mkdir -p $out
    echo "## Results wil be stored to this path: $out/"
fi

if [ "$drep" = "false" ]; then
    echo "Please provide a drep output output bin path (/path/to/drep/out/dereplicated_genomes)"
    help_message; exit 1
fi

if [ "$tmp" = "false" ]; then
    tmp=$out/temp
    mkdir -p $tmp
    echo "## No temp folder provided. Will use: $tmp"
fi


echo "## Annotate parameters:"
echo "## drep path: $drep"
echo "## Ouptut path: $out"
echo "## MicrobeAnnotator DB path: $ma_db"
echo "## GTDB DB path: $gtdb_db"
echo "## Number of threads: $threads"
echo "## Temp folder: $tmp"

echo "upload drep bins to $tmp/drep"
mkdir -p $tmp/drep
cp -f $drep/*.fa $tmp/drep/

bin_nbr=$(ls $tmp/drep/*.fa | wc -l)
echo "running metawrap annotate_bins on $bin_nbr bins"
mkdir -p $tmp/metawrap_out
singularity exec --writable-tmpfs \
-B $tmp/metawrap_out:/out \
-B $tmp/drep:/drep \
-e ${EXE_PATH}/../containers/metawrap.1.3.sif \
metaWRAP annotate_bins -t $threads \
-o /out \
-b /drep

tmp_bind=$(perl -e '
my $s = "'$tmp'";
my @t = split("/",$s);
print "/" . $t[1] . "\n";
')

ma_db_bind=$(perl -e '
my $s = "'$ma_db'";
my @t = split("/",$s);
print "/" . $t[1] . "\n";
')

out_bind=$(perl -e '
my $s = "'$out'";
my @t = split("/",$s);
print "/" . $t[1] . "\n";
')


echo "bind_path=$tmp_bind"
echo "ma_db_bind=$ma_db_bind"
echo "out_bind=$out_bind"

ma_process=$(($threads / 2))
ma_threads=2
echo "Will run microbeannotator using $ma_process precoesses and $ma_threads threads"
mkdir -p $out/microbeannotator_out
##### need to output directly in output folder or else it fails when in localscratch
singularity exec --writable-tmpfs -e \
--env MPLCONFIGDIR=$tmp \
-B $tmp_bind:$tmp_bind \
-B $ma_db_bind:/$ma_db_bind \
-B $out_bind:$out_bind \
${EXE_PATH}/../containers/microbeannotator.2.0.5.sif \
microbeannotator --method diamond --processes $ma_process --threads $ma_threads --refine \
-i $(ls $tmp/metawrap_out/bin_translated_genes/*.faa) \
-d $ma_db \
-o $out/microbeannotator_out

echo "Will run gtdbtk using $threads threads"
mkdir -p $tmp/gtdbtk_out
singularity exec --writable-tmpfs -e \
--env GTDBTK_DATA_PATH=$gtdb_db \
-B $tmp:$tmp \
-B $gtdb_db:$gtdb_db \
-e ${EXE_PATH}/../containers/gtdbtk.2.2.5.sif \
gtdbtk classify_wf --cpus $threads --genome_dir $tmp/drep --out_dir $tmp/gtdbtk_out --mash_db $gtdb_db --extension fa

echo "copying results back to $out/"
mkdir -p $out/
cp -r $tmp/metawrap_out $out
#cp -r $tmp/microbeannotator_out $out
cp -r $tmp/gtdbtk_out $out

echo "annotate pipeline done"

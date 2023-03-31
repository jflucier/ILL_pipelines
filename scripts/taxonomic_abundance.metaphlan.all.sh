#!/bin/bash -l

set -e

help_message () {
  echo ""
  echo "Usage: taxonomic_abundance.metaphlan.all.sh -profiles /path/to/metaphlan_out/*_profile.txt -o /path/to/out"
  echo "Options:"

  echo ""
  echo "	-profiles Path to metaphlan outputs (i.e. /path/to/metaphlan_out/*_profile.txt)"
  echo "	-o STR	path to output dir"
  echo "	-tmp STR	path to temp dir (default output_dir/temp)"

  echo ""
  echo "  -h --help	Display help"

	echo "";
}

export EXE_PATH=$(dirname "$0")

# initialisation
profiles="false"
out="false";
tmp="false";

# load in params
SHORT_OPTS="h:o:profiles:tmp:"
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
        -tmp) tmp=$2; shift 2;;
        -o) out=$2; shift 2;;
        -profiles) profiles=$2; shift 2;;
        --) help_message; exit 1; shift; break ;;
		*) break;;
	esac
done

if [ "$profiles" = "false" ]; then
    echo "Please provide metaphlan profiles out path i.e. /path/to/metaphlan_out/*_profile.txt."
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

echo "copying methaphlan outputs to $tmp/metaphlan"
mkdir -p $tmp/metaphlan
cp $profiles $tmp/metaphlan/

echo "copying singularity containers to $tmp"
cp ${EXE_PATH}/../containers/humann.3.6.sif $tmp/

echo "combining metaphlan profile outputs to a single table $tmp/all_profiles.txt"
singularity exec --writable-tmpfs -e \
-B $tmp:$tmp \
$tmp/humann.3.6.sif \
merge_metaphlan_tables.py $tmp/metaphlan/* > $tmp/all_profiles.tmp.txt

egrep '\|s__|clade_name' $tmp/all_profiles.tmp.txt | \
cut --complement -f2 | \
sed -e 's:_profile::g' | \
sed 's:clade_name:#Classification:' > $tmp/metaphlan_MPA_abundance.tsv

echo "copying all results to $out"
mkdir -p ${out}
cp $tmp/metaphlan_MPA_abundance.tsv ${out}/

echo "combining profile to single table done!"

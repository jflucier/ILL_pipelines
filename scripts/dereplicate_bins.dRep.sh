#!/bin/bash

set -e

help_message () {
	echo ""
	echo "Usage: dereplicate_bins.dRep.sh [-tmp /path/tmp] [-t threads] -bin_path_regex '/path/regex/to/*_genome_bins_path_regex' -o /path/to/out [-a algorithm] [-p_ani value] [-s_ani value] [-cov value] [-comp value] [-con value] "
	echo "Options:"

	echo ""
	echo "	-tmp STR	path to temp dir (default output_dir/temp)"
	echo "	-t	# of threads (default 8)"
	echo "	-bin_path_regex	A regex path to bins, i.e. /path/to/bin/*/*.fa. Must be specified between single quotes. See usage example or github documentation."
  echo "	-o STR	path to output dir"
	echo "	-a	algorithm {fastANI,ANIn,gANI,ANImf,goANI} (default: ANImf). See dRep documentation for more information."
  echo "	-p_ani	ANI threshold to form primary (MASH) clusters (default: 0.95)"
  echo "	-s_ani	ANI threshold to form secondary clusters (default: 0.99)"
  echo "	-cov	Minmum level of overlap between genomes when doing secondary comparisons (default: 0.1)"
  echo "	-comp	Minimum genome completeness (default: 50)"
	echo "	-con	Maximum genome contamination (default: 5)"
  echo ""
  echo "  -h --help	Display help"

	echo "";
}

export EXE_PATH=$(dirname "$0")

# initialisation
threads="8"
bin_path_regex="false"
out="false"
tmp="false"
algo="ANImf"
p_ani="0.95"
s_ani="0.99"
cov="0.1"
comp="50"
con="5"

# load in params
SHORT_OPTS="ht:bin_path_regex:o:a:p_ani:s_ani:cov:comp:con:tmp:"
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
        -tmp) tmp=$2; shift 2;;
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

if [ "$tmp" = "false" ]; then
    tmp=$out/temp
    mkdir -p $tmp
    echo "## No temp folder provided. Will use: $tmp"
fi

echo "## dRep parameters:"
echo "## Algorithm for secondary clustering comparisons: $algo"
echo "## ANI threshold to form primary (MASH) clusters: $p_ani"
echo "## ANI threshold to form secondary clusters: $s_ani"
echo "## Minmum level of overlap between genomes: $cov"
echo "## Minimum genome completeness: $comp"
echo "## Maximum genome contamination: $con"
echo "## Number of threads: $threads"

echo "upload bins to $tmp/bins"
mkdir $tmp/raw_bins
rm -f $tmp/raw_bins/all_fastas.txt
for bin in $bin_path_regex
do
    fn=$(basename $bin)
#    s=${fn%.bin.[0-9]*.fa}
    # symbolic link not working in drep container
    # ln -s $f test_data/${s}_${b}
    echo "/data/${fn}" >> $tmp/raw_bins/all_fastas.txt
    cp $bin $tmp/raw_bins/
done


echo "running dRep"
mkdir -p $tmp/drep_out
singularity exec --writable-tmpfs \
-B $tmp/raw_bins:/data \
-B $tmp/drep_out:/out \
-B /cvmfs/datahub.genap.ca/vhost34/def-ilafores/checkm_db:/checkm \
-e ${EXE_PATH}/../containers/dRep.3.4.0.sif \
dRep dereplicate /out/ \
--genomes /data/all_fastas.txt \
--S_algorithm $algo \
--P_ani $p_ani --S_ani $s_ani --cov_thresh $cov \
--completeness $comp --contamination $con \
--processors $threads --debug

echo "generating salmon index on drep results in $tmp/drep_out/salmon_index"
mkdir $tmp/drep_out/salmon_index
## header must be unique, add sample name
for f in $tmp/drep_out/dereplicated_genomes/*.fa
do
    echo "running $f"
    bn=$(basename $f)
    perl -ne '
    if($_ =~ /^>/){
        my $h = substr($_,1);
        my @s = split("_","'$bn'");
        print ">" . $s[0] . "_" . $h;
    }
    else{
        print $_;
    }
    ' $f > ${f}.newheader

    rm $f
    mv ${f}.newheader $f
done



echo "copying drep results back to $out/"
mkdir -p $out/
cp -r $tmp/drep_out/* $out

echo "drep pipeline done"

#!/bin/bash

set -e

help_message () {
	echo ""
	echo "Usage: dereplicate_bins.dRep.sh [-tmp /path/tmp] [-t threads] -bins_tsv all_genome_bins_path_regex -o /path/to/out -a algorithm -p_ani value -s_ani value -cov value -comp value -con value "
	echo "Options:"

	echo ""
	echo "	-tmp STR	path to temp dir (default output_dir/temp)"
	echo "	-t	# of threads (default 8)"
	echo "	-bins_tsv	A 2 column tsv of fasta bins for all samples. Columns should be sample_name<tab>/path/to/fa. No headers!"
    echo "	-o STR	path to output dir"
	echo "	-a	algorithm {fastANI,ANIn,gANI,ANImf,goANI} (default: ANImf). See dRep documentation for more information."
    echo "	-p_ani	ANI threshold to form primary (MASH) clusters (default: 0.95)"
    echo "	-s_ani	ANI threshold to form secondary clusters (default: 0.99)"
    echo "	-cov	Minmum level of overlap between genomes when doing secondary comparisons (default: 0.1)"
    echo "	-comp	Minimum genome completeness (default: 75)"
	echo "	-con	Maximum genome contamination (default: 25)"
    echo ""
    echo "  -h --help	Display help"

	echo "";
}

check_software_dependencies () {

    if ! command -v "singularity" &> /dev/null
    then
        echo "##**** singularity could not be found ****"
        echo "## Please make sure the singularity executable is in your PATH variable"
        help_message
        exit 1
    fi

	if ! command -v "salmon" &> /dev/null
    then
        echo "##**** salmon could not be found ****"
        echo "## Please make sure the salmon executable is in your PATH variable"
        help_message
        exit 1
    fi

}

export EXE_PATH=$(dirname "$0")

# check if singularity and bbmap in path
check_software_dependencies

# initialisation
threads="8"
bins_tsv="false"
out="false"
tmp="false"
algo="ANImf"
p_ani="0.95"
s_ani="0.99"
cov="0.1"
comp="75"
con="25"

# load in params
SHORT_OPTS="ht:bins_tsv:o:a:p_ani:s_ani:cov:comp:con:tmp:"
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
		-bins_tsv) bins_tsv=$2; shift 2;;
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

if [ "$bins_tsv" = "false" ]; then
    echo "Please provide a 2 column bins tsv. Columns should be sample_name<tab>/path/to/fa. No headers!"
    help_message; exit 1
else
	echo "## Genome bins tsv path: $bins_tsv"
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
mdkir $tmp/bins
rm -f $tmp/all_fastas.txt
cat $bins_tsv | while  IFS=$'\t' read  -r name path
do
	b=$(basename $path)
    echo "copying $path to $tmp/bins/${name}_${b}"
    echo "/data/${name}_${b}" >> $tmp/bins/all_fastas.txt
    cp $path $tmp/bins/${s}_${b}
done

echo "running dRep"
mkdir -p $tmp/drep_out
singularity exec --writable-tmpfs \
-B $tmp/bins:/data \
-B $tmp/drep_out:/out \
-B /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/checkm_db:/checkm \
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
for f in $tmp/drep_out/*.fa
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
done

cat $tmp/drep_out/*.newheader > $tmp/drep_out/salmon_index/bin_assembly.fa
assembly=$tmp/drep_out/salmon_index/bin_assembly.fa
salmon index -p $threads -t $assembly -i $tmp/drep_out/salmon_index


echo "copying drep results back to $out/"
mkdir -p $out/
cp -r $tmp/drep_out/* $out

echo "drep pipeline done"

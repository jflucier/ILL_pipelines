#!/bin/bash

set -e

help_message () {
	echo ""
	echo "Usage: preprocess.kneaddata.sh -s sample_name -o /path/to/out [--db] [--trimmomatic_options \"trim options\"] [--bowtie2_options \"bowtie2 options\"]"
	echo "Options:"

	echo ""
	echo "	-s STR	sample name"
    echo "	-o STR	path to output dir"
    echo "	-tmp STR	path to temp dir (default output_dir/temp)"
    echo "	-t	# of threads (default 8)"
    echo "	-m	memory (default 30G)"
    echo "	-fq1	path to fastq1"
    echo "	-fq2	path to fastq2"
    echo "	--db	path(s) to contaminant genome(s) (default /net/nfs-ip34/fast/def-ilafores/host_genomes/GRCh38_index/grch38_1kgmaj)"
    echo "  --trimmomatic_adapters  adapter file default (default ILLUMINACLIP:/cvmfs/soft.mugqic/CentOS6/software/trimmomatic/Trimmomatic-0.39/adapters/TruSeq3-PE-2.fa:2:30:10)"
    echo "  --trimmomatic_options   quality trimming options (default SLIDINGWINDOW:4:30 MINLEN:100)"
    echo "	--bowtie2_options	options to pass to trimmomatic (default --very-sensitive-local)"

    echo ""
    echo "  -h --help	Display help"

	echo "";
}

export EXE_PATH=$(dirname "$0")

# initialisation
threads="8"
mem="30G"
sample="false";
base_out="false";
tmp="false";
fq1="false";
fq2="false";
db="/net/nfs-ip34/fast/def-ilafores/host_genomes/GRCh38_index/grch38_1kgmaj"
trimmomatic_options="SLIDINGWINDOW:4:30 MINLEN:100"
trimmomatic_adapters="ILLUMINACLIP:/cvmfs/soft.mugqic/CentOS6/software/trimmomatic/Trimmomatic-0.39/adapters/TruSeq3-PE-2.fa:2:30:10"
bowtie2_options="--very-sensitive-local"

# loop through input params
while true; do
    # echo "$1=$2"
	case "$1" in
        -h | --help) help_message; exit 1; shift 1;;
        -t) threads=$2; shift 2;;
        -tmp) tmp=$2; shift 2;;
        -m) mem=$2; shift 2;;
        -s) sample=$2; shift 2;;
        -o) base_out=$2; shift 2;;
        -fq1) fq1=$2; shift 2;;
        -fq2) fq2=$2; shift 2;;
		--db) db=$2; shift 2;;
        --trimmomatic_options) trimmomatic_options=$2; shift 2;;
        --trimmomatic_adapters) trimmomatic_adapters=$2; shift 2;;
        --bowtie2_options) bowtie2_options=$2; shift 2;;
        --) help_message; exit 1; shift; break ;;
		*) break;;
	esac
done

if [ "$sample" = "false" ]; then
    echo "Please provide a sample name."
    help_message; exit 1
else
    echo "## Sample name: $sample"
fi

if [ "$base_out" = "false" ]; then
    echo "Please provide an output path"
    help_message; exit 1
else
    mkdir -p ${base_out}/${sample}
    out=${base_out}/${sample}
    echo "## Results wil be stored to this path: ${out}"
fi

if [ "$tmp" = "false" ]; then
    tmp=$out/temp
    mkdir -p $tmp
    echo "## No temp folder provided. Will use: $tmp"
fi

echo "Preprocessing and quality control of sample $sample"
echo "fastq1 path: $fq1"
echo "fastq2 path: $fq2"
echo "Will use $threads threads"
echo "Will use $mem memory"

fq1_name=$(basename $fq1)
fq2_name=$(basename $fq2)
db_name=$(basename $db)

mkdir -p $base_out/.throttle

# to prevent starting of multiple download because of simultanneneous ls
sleep $[ ( $RANDOM % 30 ) + 1 ]s

l_nbr=$(ls ${base_out}/.throttle/throttle.start.*.txt 2> /dev/null | wc -l )
while [ "$l_nbr" -ge 5 ]
do
  echo "${sample}: compute node copy reached max of 5 parralel copy, will wait 15 sec..."
  sleep 15
  l_nbr=$(ls ${base_out}/.throttle/throttle.start.*.txt 2> /dev/null | wc -l )
done

# add to throttle list
touch ${base_out}/.throttle/throttle.start.${sample}.txt

echo "upload fastq1 to $tmp/"
cp $fq1 $tmp/$fq1_name
echo "upload fastq2 to $tmp"
cp $fq2 $tmp/$fq2_name
echo "cp singularity container to $tmp"
cp ${EXE_PATH}/../containers/kneaddata.0.12.0.sif $tmp/

# remove from throttle list
rm ${base_out}/.throttle/throttle.start.${sample}.txt

h_test=$(zcat $tmp/${fq1_name} | head -n 1 | perl -ne '
if($_ =~ / 1\:.*$/){
  print "true";
}
else{
  print "false";
}
')

if [ "$h_test" = "true" ]; then
    echo "Will reformat fastq headers for kneaddata support"
    zcat $tmp/$fq1_name | sed 's/ 1:.*/\/1/g' > $tmp/paired_sorted_1.fastq
    zcat $tmp/$fq2_name | sed 's/ 2:.*/\/2/g' > $tmp/paired_sorted_2.fastq
else
    echo "Fastq headers seems to be ok. Make sure to validate output and see if alll reads go to unmatched fastq"
    zcat $tmp/$fq1_name > $tmp/paired_sorted_1.fastq
    zcat $tmp/$fq2_name > $tmp/paired_sorted_2.fastq
fi

echo "running kneaddata. kneaddata ouptut: $tmp/"
###### pas de decontamine, output = $tmp/${sample}/*repeats* --> peut changer etape pour fastp et cutadapt
basepath=$(perl -e '
  my $a = "'$db'";
  my @t = split("/",$a);
  print "/" . $t[1] . "\n";
')

singularity exec --writable-tmpfs -e \
-B $tmp:/temp \
-B ${out}:/out \
-B ${basepath}:${basepath} \
$tmp/kneaddata.0.12.0.sif \
kneaddata -v \
--log /out/kneaddata-${sample}.log \
--input1 /temp/paired_sorted_1.fastq \
--input2 /temp/paired_sorted_2.fastq \
-db ${db} \
--bowtie2-options="${bowtie2_options}" \
-o /temp/ \
--output-prefix ${sample} \
--threads ${threads} \
--max-memory ${mem} \
--trimmomatic-options="${trimmomatic_adapters} ${trimmomatic_options}" \
--run-fastqc-start \
--run-fastqc-end

echo "deleting kneaddata uncessary files"
rm $tmp/${sample}*repeats* $tmp/${sample}*trimmed* ##changer ici si pas de decontam

echo "moving contaminants fastqs to subdir"
mkdir -p $tmp/${sample}_contaminants
mv $tmp/${sample}*contam*.fastq $tmp/${sample}_contaminants/

echo "copying results to $out with throttling"

l_nbr=$(ls ${base_out}/.throttle/throttle.end.*.txt 2> /dev/null | wc -l )
while [ "$l_nbr" -ge 5 ]
do
  echo "${sample}: compute node copy reached max of 5 parralel copy, will wait 15 sec..."
  sleep 15
  l_nbr=$(ls ${base_out}/.throttle/throttle.end.*.txt 2> /dev/null | wc -l )
done

# add to throttle list
touch ${base_out}/.throttle/throttle.end.${sample}.txt

echo "copying all kneaddata results to $out"
cp -fr $tmp/${sample}* $out/
cp $tmp/fastqc/*.html $out/

# cp done remove from list
rm ${base_out}/.throttle/throttle.end.${sample}.txt

echo "done ${sample}"

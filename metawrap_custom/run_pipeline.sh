#!/bin/bash

set -e

newgrp def-ilafores
module load StdEnv/2020 gcc/9 python/3.7.9 java/14.0.2 singularity/3.7 mugqic/BBMap/38.90
# module load StdEnv/2020 gcc/9 python/3.7.9 java/14.0.2 mugqic/bowtie2/2.3.5 mugqic/trimmomatic/0.39 mugqic/samtools/1.14 mugqic/TRF/4.09 mugqic/fastqc/0.11.5
# export PATH=/cvmfs/soft.mugqic/CentOS6/software/trimmomatic/Trimmomatic-0.39:$PATH
# export PATH=/project/def-ilafores/common/SPAdes-3.15.4-Linux/bin:$PATH

#export METAWRAP_PATH=/project/def-ilafores/common/ILL_pipelines/metawrap_custom
export METAWRAP_PATH=$(dirname "$0")

# import env variables
source $1

### Preproc
source /project/def-ilafores/common/kneaddata/bin/activate
mkdir -p $SLURM_TMPDIR/${__sample}

echo "running kneaddata. kneaddata ouptut: $SLURM_TMPDIR/${__sample}/"
###### pas de decontamine, output = $SLURM_TMPDIR/${__sample}/*repeats* --> peut changer etape pour fastp et cutadapt
kneaddata -v \
--log ${OUPUT_PATH}/make_custom_buglist-${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.kneaddata.out \
--input $SLURM_TMPDIR/${__fastq_file1} \
--input $SLURM_TMPDIR/${__fastq_file2} \
-db $KNEADDATA_DB \
--bowtie2-options="'${BOWTIE2_OPTIONS}'" \
-o $SLURM_TMPDIR/${__sample} \
--output-prefix ${__sample} \
--threads ${SLURM_NBR_THREADS} \
--max-memory ${SLURM_MEMORY} \
--sequencer-source="${SEQUENCER}" \
--trimmomatic-options="${TRIMMOMATIC}" \
--run-fastqc-start \
--run-fastqc-end

deactivate

echo "deleting kneaddata uncessary files"
rm $SLURM_TMPDIR/${__sample}/*repeats* $SLURM_TMPDIR/${__sample}/*trimmed*

echo "moving contaminants fastqs to subdir"
mkdir -p $SLURM_TMPDIR/${__sample}/${__sample}_contaminants
mv $SLURM_TMPDIR/${__sample}/*contam*.fastq $SLURM_TMPDIR/${__sample}/${__sample}_contaminants/

echo "sort & reorder paired fastq prior to metawrap assembly"
repair.sh \
in=$SLURM_TMPDIR/${__sample}/${__sample}_paired_1.fastq in2=$SLURM_TMPDIR/${__sample}/${__sample}_paired_2.fastq \
out=$SLURM_TMPDIR/${__sample}/${__sample}_paired_1.sort.fastq out2=$SLURM_TMPDIR/${__sample}/${__sample}_paired_2.sort.fastq

# echo "concatenate paired output, for HUMAnN single-end run"
# cat $SLURM_TMPDIR/${__sample}/${__sample}_paired_1.fastq $SLURM_TMPDIR/${__sample}/${__sample}_paired_2.fastq > $SLURM_TMPDIR/${__sample}/${__sample}_cat-paired.fastq
echo "assembly with metawrap metaspades and megahit"
mkdir -p $SLURM_TMPDIR/${__sample}/assembly
export SPADES_MEM=$(echo $SLURM_MEMORY | perl -ne 'chomp($_); chop($_); print $_ . "\n";')
singularity exec --writable-tmpfs -e \
-B $SLURM_TMPDIR/${__sample}:/out $METAWRAP_PATH/metawrap.1.3.sif \
metaWRAP assembly --metaspades --megahit \
-m $SPADES_MEM -t $SLURM_NBR_THREADS \
-1 /out/${__sample}_paired_1.sort.fastq \
-2 /out/${__sample}_paired_2.sort.fastq \
-o /out/assembly/

# echo "create bowtie index on metaspades contigs"
# bowtie2-build --threads ${SLURM_NBR_THREADS} \
# $SLURM_TMPDIR/${__sample}/assembly/metaspades/contigs.fasta \
# $SLURM_TMPDIR/${__sample}/assembly/metaspades/contigs
#
# echo "realigning reads on metaspades contigs and keeping unmapped"
# bowtie2 --threads ${SLURM_NBR_THREADS} --very-sensitive \
# -x $SLURM_TMPDIR/${__sample}/assembly/metaspades/contigs \
# -1 $SLURM_TMPDIR/${__sample}/${__sample}_paired_1.fastq \
# -2 $SLURM_TMPDIR/${__sample}/${__sample}_paired_2.fastq \
# | samtools view --threads ${SLURM_NBR_THREADS} -S -b -f 4 \
# | samtools sort --threads ${SLURM_NBR_THREADS} -n -o $SLURM_TMPDIR/${__sample}/assembly/metaspades/unmapped.bam
#
# echo "output unmapped in fastq"
# samtools fastq --threads ${SLURM_NBR_THREADS} $SLURM_TMPDIR/${__sample}/assembly/metaspades/unmapped.bam \
# -1 $SLURM_TMPDIR/${__sample}/assembly/metaspades/unmapped.R1.fastq.gz \
# -2 $SLURM_TMPDIR/${__sample}/assembly/metaspades/unmapped.R2.fastq.gz -0 /dev/null -s /dev/null -n
#
# echo "running megahit"
# export PATH=/project/def-ilafores/common/megahit/build:$PATH
# ## on active --presets meta-large: if the metagenome is complex (i.e., bio-diversity is high, for example soil metagenomes) ????
# megahit -t ${SLURM_NBR_THREADS} \
# -1 $SLURM_TMPDIR/${__sample}/assembly/metaspades/unmapped.R1.fastq.gz \
# -2 $SLURM_TMPDIR/${__sample}/assembly/metaspades/unmapped.R2.fastq.gz \
# -o $SLURM_TMPDIR/${__sample}/assembly/megahit
#
# echo "combine metaspades & megahit contigs"
# ### quickmerge???
# cat \
# $SLURM_TMPDIR/${__sample}/assembly/metaspades/contigs.fasta \
# $SLURM_TMPDIR/${__sample}/assembly/megahit/final.contigs.fa \
# > $SLURM_TMPDIR/${__sample}/assembly/${__sample}.contigs.fasta
#
# perl -e '
# open(my $FA, "<'$SLURM_TMPDIR'/'${__sample}'/assembly/'${__sample}'.contigs.fasta");
# my @lines = <$FA>;
# chomp(@lines);
# my $c = 1;
# foreach my $l (@lines){
#     if($l =~ /^\>/){
#         print ">tmp_" . $c . "\n";
#         $c++;
#     }
#     else{
#         print $l . "\n";
#     }
# }
# ' > $SLURM_TMPDIR/${__sample}/assembly/${__sample}.contigs.reformat.fasta
#
# echo "create bowtie index on all contigs"
# bowtie2-build --threads ${SLURM_NBR_THREADS} \
# $SLURM_TMPDIR/${__sample}/assembly/${__sample}.contigs.reformat.fasta \
# $SLURM_TMPDIR/${__sample}/assembly/${__sample}.contigs.reformat
#
# echo "realigning reads on all contigs"
# bowtie2 --threads ${SLURM_NBR_THREADS} --very-sensitive \
# -x $SLURM_TMPDIR/${__sample}/assembly/${__sample}.contigs.reformat \
# -1 $SLURM_TMPDIR/${__sample}/${__sample}_paired_1.fastq \
# -2 $SLURM_TMPDIR/${__sample}/${__sample}_paired_2.fastq \
# | samtools sort --threads ${SLURM_NBR_THREADS} -l 5 -o $SLURM_TMPDIR/${__sample}/assembly/${__sample}.contigs.sorted.bam
#
# samtools index -@ ${SLURM_NBR_THREADS} $SLURM_TMPDIR/${__sample}/assembly/${__sample}.contigs.sorted.bam
#
# echo "get insert size average and stddev"
# module load r/4.1.0 mugqic/picard/2.26.6
# java -jar $PICARD_HOME/picard.jar CollectInsertSizeMetrics \
# I=$SLURM_TMPDIR/${__sample}/assembly/${__sample}.contigs.sorted.bam \
# O=$SLURM_TMPDIR/${__sample}/assembly/${__sample}.insert_size_metrics.txt \
# H=$SLURM_TMPDIR/${__sample}/assembly/${__sample}.insert_size_histogram.pdf \
# M=0.5
#
# module load singularity/3.7

echo "binning with metawrap"
cp $SLURM_TMPDIR/${__sample}/${__sample}_paired_1.sort.fastq $SLURM_TMPDIR/${__sample}/${__sample}_paired_sorted_1.fastq
cp $SLURM_TMPDIR/${__sample}/${__sample}_paired_2.sort.fastq $SLURM_TMPDIR/${__sample}/${__sample}_paired_sorted_2.fastq

mkdir $SLURM_TMPDIR/${__sample}/binning/
export BINNING_MEM=$(echo $SLURM_MEMORY | perl -ne 'chomp($_); chop($_); print $_ . "\n";')
singularity exec --writable-tmpfs -e \
-B $SLURM_TMPDIR/${__sample}:/out $METAWRAP_PATH/metawrap.1.3.sif \
metaWRAP binning --metabat2 --maxbin2 --concoct --run-checkm \
-m $BINNING_MEM -t $SLURM_NBR_THREADS \
-a /out/assembly/final_assembly.fasta \
-o /out/binning/ \
/out/${__sample}_paired_sorted_1.fastq /out/${__sample}_paired_sorted_2.fastq

echo "binning refinement with metawrap"
singularity exec --writable-tmpfs -e \
-B $SLURM_TMPDIR/${__sample}:/out $METAWRAP_PATH/metawrap.1.3.sif \
metaWRAP bin_refinement



echo "metabat: generate depth file"
singularity exec --writable-tmpfs -e \
-B $SLURM_TMPDIR/${__sample}:/out \
/project/def-ilafores/common/ILL_pipelines/metawrap_custom/metabat.2.15.5.sif \
jgi_summarize_bam_contig_depths \
--outputDepth /out/binning/${__sample}.contigs.sorted.depth.tbl \
--referenceFasta /out/assembly/${__sample}.contigs.reformat.fasta \
/out/assembly/${__sample}.contigs.sorted.bam

echo "metabat: binning contigs"
mkdir $SLURM_TMPDIR/${__sample}/binning/metabat_output/
singularity exec --writable-tmpfs -e \
-B $SLURM_TMPDIR/${__sample}:/out \
/project/def-ilafores/common/ILL_pipelines/metawrap_custom/metabat.2.15.5.sif \
metabat2 -v -t ${SLURM_NBR_THREADS} --unbinned \
-i /out/assembly/${__sample}.contigs.reformat.fasta \
-a /out/binning/${__sample}.contigs.sorted.depth.tbl \
-o /out/binning/metabat_output/${__sample}.metabat

echo "binning contigs using maxbin"
mkdir $SLURM_TMPDIR/${__sample}/binning/maxbin_output/
cut -f 1,3 $SLURM_TMPDIR/${__sample}/binning/${__sample}.contigs.sorted.depth.tbl > $SLURM_TMPDIR/${__sample}/binning/${__sample}.contigs.sorted.depth.maxbin.tbl
sed -i '1d' $SLURM_TMPDIR/${__sample}/binning/${__sample}.contigs.sorted.depth.maxbin.tbl
perl /project/def-ilafores/common/MaxBin-2.2.7/run_MaxBin.pl -thread ${SLURM_NBR_THREADS} \
-contig $SLURM_TMPDIR/${__sample}/assembly/${__sample}.contigs.reformat.fasta \
-abund $SLURM_TMPDIR/${__sample}/binning/${__sample}.contigs.sorted.depth.maxbin.tbl \
-out $SLURM_TMPDIR/${__sample}/binning/maxbin_output/${__sample}.maxbin


#$SLURM_TMPDIR/${__sample}/assembly/${__sample}.contigs.reformat.fasta
echo "concoct: runnin cut_up_fasta.py"
singularity exec --writable-tmpfs -e \
-B $SLURM_TMPDIR/${__sample}/assembly:/out \
/project/def-ilafores/common/ILL_pipelines/metawrap_custom/concoct.1.1.0.sif \
cut_up_fasta.py /out/${__sample}.contigs.reformat.fasta -c 10000 -o 0 --merge_last -b /out/${__sample}.contigs_10K.bed > $SLURM_TMPDIR/${__sample}/assembly/${__sample}.contigs_10K.fa

echo "concoct: runnin concoct_coverage_table.py"
singularity exec --writable-tmpfs -e \
-B $SLURM_TMPDIR/${__sample}/assembly:/out \
/project/def-ilafores/common/ILL_pipelines/metawrap_custom/concoct.1.1.0.sif \
concoct_coverage_table.py /out/${__sample}.contigs_10K.bed /out/${__sample}.contigs.sorted.bam > $SLURM_TMPDIR/${__sample}/assembly/${__sample}.coverage_table.tsv

echo "concoct: runnin concoct"
mkdir $SLURM_TMPDIR/${__sample}/binning/concoct_output/
singularity exec --writable-tmpfs -e \
-B $SLURM_TMPDIR/${__sample}:/out \
/project/def-ilafores/common/ILL_pipelines/metawrap_custom/concoct.1.1.0.sif \
concoct --threads ${SLURM_NBR_THREADS} --composition_file /out/assembly/${__sample}.contigs_10K.fa --coverage_file /out/assembly/${__sample}.coverage_table.tsv -b /out/binning/concoct_output/

### curreently fails: sent issue to dev https://github.com/BinPro/CONCOCT/issues/312
echo "concoct: runnin extract_fasta_bins.py"
singularity exec --writable-tmpfs -e \
-B $SLURM_TMPDIR/${__sample}:/out \
/project/def-ilafores/common/ILL_pipelines/metawrap_custom/concoct.1.1.0.sif \
extract_fasta_bins.py /out/assembly/${__sample}.contigs.reformat.fasta /out/binning/concoct_output/clustering_gt1000.csv --output_path /out/binning/concoct_output/fasta_bins

echo "concoct: done!"

echo "binning contigs using maxbin2"
mkdir $SLURM_TMPDIR/${__sample}/binning/maxbin_output/

















zzzz

#!/bin/bash

set -e

newgrp def-ilafores
module load StdEnv/2020 gcc/9 python/3.7.9 java/14.0.2 mugqic/bowtie2/2.3.5 mugqic/trimmomatic/0.39 mugqic/samtools/1.14 mugqic/TRF/4.09 mugqic/fastqc/0.11.5
export PATH=/cvmfs/soft.mugqic/CentOS6/software/trimmomatic/Trimmomatic-0.39:$PATH
export PATH=/project/def-ilafores/common/SPAdes-3.15.4-Linux/bin:$PATH


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

# echo "concatenate paired output, for HUMAnN single-end run"
# cat $SLURM_TMPDIR/${__sample}/${__sample}_paired_1.fastq $SLURM_TMPDIR/${__sample}/${__sample}_paired_2.fastq > $SLURM_TMPDIR/${__sample}/${__sample}_cat-paired.fastq
echo "assembly with metaspades"
mkdir -p $SLURM_TMPDIR/${__sample}/assembly/metaspades
mkdir -p $SLURM_TMPDIR/${__sample}/assembly/tmp
export SPADES_MEM=$(echo $SLURM_MEMORY | perl -ne 'chomp($_); chop($_); print $_ . "\n";')
metaspades.py -m $SPADES_MEM -t $SLURM_NBR_THREADS \
-1 $SLURM_TMPDIR/${__sample}/${__sample}_paired_1.fastq \
-2 $SLURM_TMPDIR/${__sample}/${__sample}_paired_2.fastq \
-o $SLURM_TMPDIR/${__sample}/assembly/metaspades/ \
--tmp-dir $SLURM_TMPDIR/${__sample}/assembly/tmp

echo "create bowtie index on metaspades contigs"
bowtie2-build --threads ${SLURM_NBR_THREADS} \
$SLURM_TMPDIR/${__sample}/assembly/metaspades/contigs.fasta \
$SLURM_TMPDIR/${__sample}/assembly/metaspades/contigs

echo "realigning reads on metaspades contigs and keeping unmapped"
bowtie2 --threads ${SLURM_NBR_THREADS} --very-sensitive \
-x $SLURM_TMPDIR/${__sample}/assembly/metaspades/contigs \
-1 $SLURM_TMPDIR/${__sample}/${__sample}_paired_1.fastq \
-2 $SLURM_TMPDIR/${__sample}/${__sample}_paired_2.fastq \
| samtools view --threads ${SLURM_NBR_THREADS} -S -b -f 4 \
| samtools sort --threads ${SLURM_NBR_THREADS} -n -o $SLURM_TMPDIR/${__sample}/assembly/metaspades/unmapped.bam

echo "output unmapped in fastq"
samtools fastq --threads ${SLURM_NBR_THREADS} $SLURM_TMPDIR/${__sample}/assembly/metaspades/unmapped.bam \
-1 $SLURM_TMPDIR/${__sample}/assembly/metaspades/unmapped.R1.fastq.gz \
-2 $SLURM_TMPDIR/${__sample}/assembly/metaspades/unmapped.R2.fastq.gz -0 /dev/null -s /dev/null -n

echo "running megahit"
export PATH=/project/def-ilafores/common/megahit/build:$PATH
## on active --presets meta-large: if the metagenome is complex (i.e., bio-diversity is high, for example soil metagenomes) ????
megahit -t ${SLURM_NBR_THREADS} \
-1 $SLURM_TMPDIR/${__sample}/assembly/metaspades/unmapped.R1.fastq.gz \
-2 $SLURM_TMPDIR/${__sample}/assembly/metaspades/unmapped.R2.fastq.gz \
-o $SLURM_TMPDIR/${__sample}/assembly/megahit

echo "combine metaspades & megahit contigs"
### quickmerge???
cat \
$SLURM_TMPDIR/${__sample}/assembly/metaspades/contigs.fasta \
$SLURM_TMPDIR/${__sample}/assembly/megahit/final.contigs.fa \
> $SLURM_TMPDIR/${__sample}/assembly/${__sample}.contigs.fasta

echo "binning contigs using concoct"
singularity exec --writable-tmpfs -e -B $SLURM_TMPDIR/${__sample}/assembly:/out concoct.1.1.0.sif ls /out

cut_up_fasta.py original_contigs.fa -c 10000 -o 0 --merge_last -b contigs_10K.bed > contigs_10K.fa
concoct_coverage_table.py contigs_10K.bed mapping/Sample*.sorted.bam > coverage_table.tsv
concoct --composition_file contigs_10K.fa --coverage_file coverage_table.tsv -b concoct_output/
mkdir concoct_output/fasta_bins
extract_fasta_bins.py original_contigs.fa concoct_output/clustering_merged.csv --output_path concoct_output/fasta_bins














zzzz

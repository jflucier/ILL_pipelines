#!/bin/bash

set -e

newgrp def-ilafores

export METAWRAP_PATH=$(dirname "$0")
echo "loading environment"
module load StdEnv/2020 gcc/9 python/3.7.9 java/14.0.2 singularity/3.7 mugqic/BBMap/38.90

# import env variables
source $1
export __sample=$2
export __fastq_file1=$3
export __fastq_file2=$4

echo "analysing sample $__sample with metawrap"
echo "fastq1 path: $__fastq_file1"
echo "fastq2 path: $__fastq_file2"

fastq1_name=$(basename $__fastq_file1)
fastq2_name=$(basename $__fastq_file2)

echo "upload fastq1 to $SLURM_TMPDIR/${__sample}/"
cp $__fastq_file1 $SLURM_TMPDIR/${__sample}/${fastq1_name}
echo "upload fastq2 to $SLURM_TMPDIR/${__sample}/"
cp $__fastq_file2 $SLURM_TMPDIR/${__sample}/${fastq2_name}

### Preproc
source /project/def-ilafores/common/kneaddata/bin/activate
mkdir -p $SLURM_TMPDIR/${__sample}

echo "running kneaddata. kneaddata ouptut: $SLURM_TMPDIR/${__sample}/"
###### pas de decontamine, output = $SLURM_TMPDIR/${__sample}/*repeats* --> peut changer etape pour fastp et cutadapt
kneaddata -v \
--log ${OUPUT_PATH}/make_custom_buglist-${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.kneaddata.out \
--input $SLURM_TMPDIR/${__sample}/${fastq1_name} \
--input $SLURM_TMPDIR/${__sample}/${fastq2_name} \
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

echo "sort & reorder paired fastq prior to metawrap assembly using bbmap"
repair.sh \
in=$SLURM_TMPDIR/${__sample}/${__sample}_paired_1.fastq in2=$SLURM_TMPDIR/${__sample}/${__sample}_paired_2.fastq \
out=$SLURM_TMPDIR/${__sample}/${__sample}_paired_sorted_1.fastq out2=$SLURM_TMPDIR/${__sample}/${__sample}_paired_sorted_2.fastq

echo "metawrap assembly step using metaspades and megahit"
mkdir -p $SLURM_TMPDIR/${__sample}/assembly
export SPADES_MEM=$(echo $SLURM_MEMORY | perl -ne 'chomp($_); chop($_); print $_ . "\n";')
singularity exec --writable-tmpfs -e \
-B $SLURM_TMPDIR/${__sample}:/out \
-B /ssdpool/shared/ilafores_group/checkm_db:/checkm \
-B /ssdpool/shared/ilafores_group/NCBI_nt:/NCBI_nt \
-B /ssdpool/shared/ilafores_group/NCBI_tax:/NCBI_tax \
$METAWRAP_PATH/metawrap.1.3.sif \
metaWRAP assembly --metaspades --megahit \
-m $SPADES_MEM -t $SLURM_NBR_THREADS \
-1 /out/${__sample}_paired_sorted_1.fastq \
-2 /out/${__sample}_paired_sorted_2.fastq \
-o /out/assembly/

# echo "renaming fastq"
# mv $SLURM_TMPDIR/${__sample}/${__sample}_paired_1.sort.fastq $SLURM_TMPDIR/${__sample}/${__sample}_paired_sorted_1.fastq
# mv $SLURM_TMPDIR/${__sample}/${__sample}_paired_2.sort.fastq $SLURM_TMPDIR/${__sample}/${__sample}_paired_sorted_2.fastq

# around 9hr of exec
echo "metawrap binning and checkm step using metabat2, maxbin2 and concoct"
mkdir $SLURM_TMPDIR/${__sample}/binning/
export BINNING_MEM=$(echo $SLURM_MEMORY | perl -ne 'chomp($_); chop($_); print $_ . "\n";')
singularity exec --writable-tmpfs -e \
-B $SLURM_TMPDIR/${__sample}:/out \
-B /ssdpool/shared/ilafores_group/checkm_db:/checkm \
-B /ssdpool/shared/ilafores_group/NCBI_nt:/NCBI_nt \
-B /ssdpool/shared/ilafores_group/NCBI_tax:/NCBI_tax \
$METAWRAP_PATH/metawrap.1.3.sif \
metaWRAP binning --metabat2 --maxbin2 --concoct --run-checkm \
-m $BINNING_MEM -t $SLURM_NBR_THREADS \
-a /out/assembly/final_assembly.fasta \
-o /out/binning/ \
/out/${__sample}_paired_sorted_1.fastq /out/${__sample}_paired_sorted_2.fastq

# around 2.5 hr of exec
echo "metawrap bin refinement"
mkdir $SLURM_TMPDIR/${__sample}/bin_refinement/
singularity exec --writable-tmpfs -e \
-B $SLURM_TMPDIR/${__sample}:/out \
-B /ssdpool/shared/ilafores_group/checkm_db:/checkm \
-B /ssdpool/shared/ilafores_group/NCBI_nt:/NCBI_nt \
-B /ssdpool/shared/ilafores_group/NCBI_tax:/NCBI_tax \
$METAWRAP_PATH/metawrap.1.3.sif \
metawrap bin_refinement -t $SLURM_NBR_THREADS -c $BIN_REFINEMENT_MIN_COMPLETION -x $BIN_REFINEMENT_MAX_CONTAMINATION \
-o /out/bin_refinement/ \
-A /out/binning/metabat2_bins/ \
-B /out/binning/maxbin2_bins/ \
-C /out/binning/concoct_bins/

echo "metawrap bin reassembly"
mkdir $SLURM_TMPDIR/${__sample}/bin_reassembly/
singularity exec --writable-tmpfs -e \
-B $SLURM_TMPDIR/${__sample}:/out \
-B /ssdpool/shared/ilafores_group/checkm_db:/checkm \
-B /ssdpool/shared/ilafores_group/NCBI_nt:/NCBI_nt \
-B /ssdpool/shared/ilafores_group/NCBI_tax:/NCBI_tax \
$METAWRAP_PATH/metawrap.1.3.sif \
metawrap reassemble_bins -t $SLURM_NBR_THREADS -m 800 -c 50 -x 10 \
-o /out/bin_reassembly/ \
-1 /out/${__sample}_paired_sorted_1.fastq \
-2 /out/${__sample}_paired_sorted_2.fastq \
-b /out/bin_refinement/metawrap_50_10_bins

echo "metawrap bin classification"
mkdir $SLURM_TMPDIR/${__sample}/bin_classification/
singularity exec --writable-tmpfs -e \
-B $SLURM_TMPDIR/${__sample}:/out \
-B /ssdpool/shared/ilafores_group/checkm_db:/checkm \
-B /ssdpool/shared/ilafores_group/NCBI_nt:/NCBI_nt \
-B /ssdpool/shared/ilafores_group/NCBI_tax:/NCBI_tax \
$METAWRAP_PATH/metawrap.1.3.sif \
metawrap classify_bins -b /out/bin_reassembly/reassembled_bins -o /out/bin_classification -t $SLURM_NBR_THREADS

echo "metawrap bin annotation"
mkdir $SLURM_TMPDIR/${__sample}/bin_annotation/
singularity exec --writable-tmpfs -e \
-B $SLURM_TMPDIR/${__sample}:/out \
-B /ssdpool/shared/ilafores_group/checkm_db:/checkm \
-B /ssdpool/shared/ilafores_group/NCBI_nt:/NCBI_nt \
-B /ssdpool/shared/ilafores_group/NCBI_tax:/NCBI_tax \
$METAWRAP_PATH/metawrap.1.3.sif \
metaWRAP annotate_bins -o /out/bin_annotation/ -t $SLURM_NBR_THREADS -b /out/bin_reassembly/reassembled_bins/

echo "copying results back to $OUPUT_PATH"
cp -r $SLURM_TMPDIR/${__sample} $OUPUT_PATH/

echo "metawrap pipeline done"













zzzz

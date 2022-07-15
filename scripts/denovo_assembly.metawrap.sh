#!/bin/bash

set -e

echo "load and valdiate env"
# load and valdiate env
export EXE_PATH=$(dirname "$0")

if [ -z ${1+x} ]; then
    echo "Please provide a configuration file. See ${EXE_PATH}/my.example.config for an example."
    exit 1
fi

export CONF_PARAMETERS=$1
export TMP_DIR=$2
export __line_nbr=$3

module load StdEnv/2020 gcc/9 python/3.7.9 java/14.0.2 singularity/3.7 mugqic/BBMap/38.90

# import env variables
source $CONF_PARAMETERS

${EXE_PATH}/global.checkenv.sh
#${EXE_PATH}/preprocess.checkenv.sh

export __sample_line=$(cat ${ASSEMBLY_SAMPLE_LIST_TSV} | awk "NR==$__line_nbr")
export __sample=$(echo -e "$__sample_line" | cut -f1)
export __fastq_file1=$(echo -e "$__sample_line" | cut -f2)
export __fastq_file2=$(echo -e "$__sample_line" | cut -f3)

echo "analysing sample $__sample with metawrap"
echo "fastq1 path: $__fastq_file1"
echo "fastq2 path: $__fastq_file2"

mkdir -p ${TMP_DIR}/${__sample}/
fastq1_name=$(basename $__fastq_file1)
fastq2_name=$(basename $__fastq_file2)

echo "upload fastq1 to ${TMP_DIR}/${__sample}/"
cp $__fastq_file1 ${TMP_DIR}/${__sample}/${fastq1_name}
echo "upload fastq2 to ${TMP_DIR}/${__sample}/"
cp $__fastq_file2 ${TMP_DIR}/${__sample}/${fastq2_name}

echo "sort & reorder paired fastq using bbmap prior to metawrap assembly"
repair.sh \
in=${TMP_DIR}/${__sample}/${fastq1_name} \
in2=${TMP_DIR}/${__sample}/${fastq2_name} \
out=${TMP_DIR}/${__sample}/${__sample}_paired_sorted_1.fastq \
out2=${TMP_DIR}/${__sample}/${__sample}_paired_sorted_2.fastq

# echo "combining all sample reads for asssembly"
# cat $ASSEMBLY_SAMPLE_F1_PATH_REGEX > ${TMP_DIR}/ALL_READS_1.fastq
# cat $ASSEMBLY_SAMPLE_F2_PATH_REGEX > ${TMP_DIR}/ALL_READS_2.fastq

echo "metawrap assembly step using metaspades and megahit"
mkdir -p ${TMP_DIR}/assembly
export SPADES_MEM=$(echo $ASSEMBLY_SLURM_MEMORY | perl -ne 'chomp($_); chop($_); print $_ . "\n";')
singularity exec --writable-tmpfs -e \
-B ${TMP_DIR}:/out \
-B /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/checkm_db:/checkm \
-B /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/NCBI_nt:/NCBI_nt \
-B /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/NCBI_tax:/NCBI_tax \
${EXE_PATH}/../containers/metawrap.1.3.sif \
metaWRAP assembly --metaspades --megahit \
-m $SPADES_MEM -t $ASSEMBLY_SLURM_NBR_THREADS \
-1 /out/${__sample}/${__sample}_paired_sorted_1.fastq \
-2 /out/${__sample}/${__sample}_paired_sorted_2.fastq \
-o /out/assembly/

echo "copying assembly results back to $OUTPUT_PATH/assembly/${__sample}/"
mkdir -p $OUTPUT_PATH/${ASSEMBLY_OUTPUT_NAME}/assembly/${__sample}/
cp -r ${TMP_DIR}/assembly/* $OUTPUT_PATH/${ASSEMBLY_OUTPUT_NAME}/assembly/${__sample}/

# echo "renaming fastq"
# mv ${TMP_DIR}/${__sample}/${__sample}_paired_1.sort.fastq ${TMP_DIR}/${__sample}/${__sample}_paired_sorted_1.fastq
# mv ${TMP_DIR}/${__sample}/${__sample}_paired_2.sort.fastq ${TMP_DIR}/${__sample}/${__sample}_paired_sorted_2.fastq

# around 9hr of exec
echo "metawrap binning and checkm step using metabat2, maxbin2 and concoct"
mkdir ${TMP_DIR}/binning/
export BINNING_MEM=$(echo $ASSEMBLY_SLURM_MEMORY | perl -ne 'chomp($_); chop($_); print $_ . "\n";')
singularity exec --writable-tmpfs -e \
-B ${TMP_DIR}:/out \
-B /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/checkm_db:/checkm \
-B /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/NCBI_nt:/NCBI_nt \
-B /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/NCBI_tax:/NCBI_tax \
${EXE_PATH}/../containers/metawrap.1.3.sif \
metaWRAP binning --metabat2 --maxbin2 --concoct --run-checkm \
-m $BINNING_MEM -t $ASSEMBLY_SLURM_NBR_THREADS \
-a /out/assembly/final_assembly.fasta \
-o /out/binning/ \
/out/${__sample}/${__sample}_paired_sorted_1.fastq /out/${__sample}/${__sample}_paired_sorted_2.fastq

echo "copying binning results back to $OUTPUT_PATH/binning/${__sample}/"
mkdir -p $OUTPUT_PATH/${ASSEMBLY_OUTPUT_NAME}/binning/${__sample}/
cp -r ${TMP_DIR}/binning/* $OUTPUT_PATH/${ASSEMBLY_OUTPUT_NAME}/binning/${__sample}/

# around 2.5 hr of exec
echo "metawrap bin refinement"
mkdir ${TMP_DIR}/bin_refinement/
singularity exec --writable-tmpfs -e \
-B ${TMP_DIR}:/out \
-B /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/checkm_db:/checkm \
-B /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/NCBI_nt:/NCBI_nt \
-B /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/NCBI_tax:/NCBI_tax \
${EXE_PATH}/../containers/metawrap.1.3.sif \
metawrap bin_refinement -t $ASSEMBLY_SLURM_NBR_THREADS --quick \
-c $BIN_REFINEMENT_MIN_COMPLETION -x $BIN_REFINEMENT_MAX_CONTAMINATION \
-o /out/bin_refinement/ \
-A /out/binning/metabat2_bins/ \
-B /out/binning/maxbin2_bins/ \
-C /out/binning/concoct_bins/

echo "copying bin_refinement results back to $OUTPUT_PATH/bin_refinement/${__sample}/"
mkdir -p $OUTPUT_PATH/${ASSEMBLY_OUTPUT_NAME}/bin_refinement/${__sample}/
cp -r ${TMP_DIR}/bin_refinement/* $OUTPUT_PATH/${ASSEMBLY_OUTPUT_NAME}/bin_refinement/${__sample}/


# echo "metawrap bin reassembly"
# mkdir ${TMP_DIR}/bin_reassembly/
# export BINNING_MEM=$(echo $ASSEMBLY_SLURM_MEMORY | perl -ne 'chomp($_); chop($_); print $_ . "\n";')
# singularity exec --writable-tmpfs -e \
# -B ${TMP_DIR}:/out \
# -B /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/checkm_db:/checkm \
# -B /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/NCBI_nt:/NCBI_nt \
# -B /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/NCBI_tax:/NCBI_tax \
# ${EXE_PATH}/../containers/metawrap.1.3.sif \
# metawrap reassemble_bins -t $ASSEMBLY_SLURM_NBR_THREADS -m $BINNING_MEM \
# -c $ASSEMBLY_BIN_REFINEMENT_MIN_COMPLETION -x $ASSEMBLY_BIN_REFINEMENT_MAX_CONTAMINATION \
# -o /out/bin_reassembly/ \
# -1 /out/ALL_READS_1.fastq \
# -2 /out/ALL_READS_2.fastq \
# -b /out/bin_refinement/metawrap_${ASSEMBLY_BIN_REFINEMENT_MIN_COMPLETION}_${ASSEMBLY_BIN_REFINEMENT_MAX_CONTAMINATION}_bins

# cp -r ${TMP_DIR}/bin_reassembly $OUTPUT_PATH/





echo "metawrap assembly & binning pipeline done"

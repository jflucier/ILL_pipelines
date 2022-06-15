#!/bin/bash

set -e

echo "################################################################################################################"

echo "## checking if all humann custom variables are properly defined"

if [[ -z "${PREPROCESS_SAMPLES_LIST_TSV}" ]]; then
    echo "## FATAL: SAMPLE_TSV variable must be defined. To set, edit config file: export PREPROCESS_SAMPLES_LIST_TSV=/path/to/sample.tsv"
    exit 1
elif [ ! -f "$PREPROCESS_SAMPLES_LIST_TSV" ]; then
    echo "## FATAL: $PREPROCESS_SAMPLES_LIST_TSV file does not exist. Please specifiy a valid path. To set, edit config file: export PREPROCESS_SAMPLES_LIST_TSV=/path/to/sample.tsv"
    exit 1
fi
echo "## SAMPLE_TSV datapath: $PREPROCESS_SAMPLES_LIST_TSV"

if [ ! -f "${PREPROCESS_KNEADDATA_DB}.1.bt2" ]
then

    echo "##**** KNEADDATA Bowtie2 db index not found. ****"
    echo "## Please verify. An index file with the following name should be found: ${PREPROCESS_KNEADDATA_DB}.1.bt2"
    echo "##**********************************"
    echo "##"
    exit 1
fi

if [[ -z "${PREPROCESS_KNEADDATA_SEQUENCER}" ]]; then
    echo "##**********************************"
    echo "## WARNING: KNEADDATA PREPROCESS_KNEADDATA_SEQUENCER option is not defined. To set, edit config file: export PREPROCESS_KNEADDATA_SEQUENCER=<<PREPROCESS_KNEADDATA_SEQUENCER type>>"
    echo "## Will set PREPROCESS_KNEADDATA_SEQUENCER to default TruSeq3"
    echo "##**********************************"
    echo "##"
    export PREPROCESS_KNEADDATA_SEQUENCER="TruSeq3"
else
    echo "## PREPROCESS_KNEADDATA_SEQUENCER: $PREPROCESS_KNEADDATA_SEQUENCER"
fi

if [[ -z "${PREPROCESS_KNEADDATA_TRIMMOMATIC}" ]]; then
    echo "##**********************************"
    echo "## WARNING: PREPROCESS_KNEADDATA_TRIMMOMATIC options is not defined. To set, edit config file: export PREPROCESS_KNEADDATA_TRIMMOMATIC=<<option passed to PREPROCESS_KNEADDATA_TRIMMOMATIC>>"
    echo "## Will set PREPROCESS_KNEADDATA_TRIMMOMATIC to default MINLEN:50 SLIDINGWINDOW:4:30"
    echo "##**********************************"
    echo "##"
    export PREPROCESS_KNEADDATA_TRIMMOMATIC="MINLEN:50 SLIDINGWINDOW:4:30"
else
    echo "## PREPROCESS_KNEADDATA_TRIMMOMATIC options: $PREPROCESS_KNEADDATA_TRIMMOMATIC"
fi

if [[ -z "${PREPROCESS_KNEADDATA_BOWTIE2_OPTIONS}" ]]; then
    echo "##**********************************"
    echo "## WARNING: PREPROCESS_KNEADDATA_BOWTIE2_OPTIONS options is not defined. To set, edit config file: export PREPROCESS_KNEADDATA_BOWTIE2_OPTIONS=<<option passed to bowtie2>>"
    echo "## Will set PREPROCESS_KNEADDATA_BOWTIE2_OPTIONS to default --very-sensitive"
    echo "##**********************************"
    echo "##"
    export PREPROCESS_KNEADDATA_BOWTIE2_OPTIONS="--very-sensitive"
else
    echo "## PREPROCESS_KNEADDATA_BOWTIE2_OPTIONS options: $PREPROCESS_KNEADDATA_BOWTIE2_OPTIONS"
fi

if [[ -z "${PREPROCESS_SLURM_WALLTIME}" ]]; then
    echo "##**********************************"
    echo "## WARNING: PREPROCESS_SLURM_WALLTIME is not defined. To set, edit config file: export PREPROCESS_SLURM_WALLTIME=<<HH:MM:SS>>"
    echo "## Will set PREPROCESS_SLURM_WALLTIME to default PREPROCESS_SLURM_WALLTIME=35:00:00"
    echo "##**********************************"
    echo "##"
    export PREPROCESS_SLURM_WALLTIME="35:00:00"
else
    echo "## PREPROCESS_SLURM_WALLTIME: $PREPROCESS_SLURM_WALLTIME"
fi

if [[ -z "${PREPROCESS_SLURM_NBR_THREADS}" ]]; then
    echo "##**********************************"
    echo "## WARNING: PREPROCESS_SLURM_NBR_THREADS is not defined. To set, edit config file: export PREPROCESS_SLURM_NBR_THREADS=<<thread_nbr>>"
    echo "## Will set PREPROCESS_SLURM_NBR_THREADS to default PREPROCESS_SLURM_NBR_THREADS=24"
    echo "##**********************************"
    echo "##"
    export PREPROCESS_SLURM_NBR_THREADS=24
else
    echo "## PREPROCESS_SLURM_NBR_THREADS: $PREPROCESS_SLURM_NBR_THREADS"
fi

if [[ -z "${PREPROCESS_SLURM_MEMORY}" ]]; then
    echo "##**********************************"
    echo "## WARNING: PREPROCESS_SLURM_MEMORY is not defined. To set, edit config file: export PREPROCESS_SLURM_MEMORY=<<mem_in_G>>"
    echo "## Will set PREPROCESS_SLURM_MEMORY to default PREPROCESS_SLURM_MEMORY=125G"
    echo "##**********************************"
    echo "##"
    export PREPROCESS_SLURM_MEMORY="125G"
else
    echo "## PREPROCESS_SLURM_MEMORY: $PREPROCESS_SLURM_MEMORY"
fi


echo "################################################################################################################"

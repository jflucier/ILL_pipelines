#!/bin/bash

set -e

echo "################################################################################################################"

echo "## checking if all humann custom variables are properly defined"

if [[ -z "${TAXONOMIC_SAMPLE_SAMPLES_LIST_TSV}" ]]; then
    echo "## FATAL: SAMPLE_TSV variable must be defined. To set, edit config file: export TAXONOMIC_SAMPLE_SAMPLES_LIST_TSV=/path/to/sample.tsv"
    exit 1
elif [ ! -f "$TAXONOMIC_SAMPLE_SAMPLES_LIST_TSV" ]; then
    echo "## FATAL: $TAXONOMIC_SAMPLE_SAMPLES_LIST_TSV file does not exist. Please specifiy a valid path. To set, edit config file: export TAXONOMIC_SAMPLE_SAMPLES_LIST_TSV=/path/to/sample.tsv"
    exit 1
fi
echo "## SAMPLE_TSV datapath: $TAXONOMIC_SAMPLE_SAMPLES_LIST_TSV"

if [ ! -f "${TAXONOMIC_SAMPLE_KRAKEN2_DB_PATH}/hash.k2d" ]
then

    echo "##**** KRAKEN2 database index not found. ****"
    echo "## Please verify. An index file with the following name should be found: ${TAXONOMIC_SAMPLE_KRAKEN2_DB_PATH}/hash.k2d"
    echo "##**********************************"
    echo "##"
    exit 1
fi

if [[ -z "${TAXONOMIC_SAMPLE_LEVEL}" ]]; then
    echo "##**********************************"
    echo "## WARNING: TAXONOMIC_SAMPLE_LEVEL option is not defined. To set, edit config file: export TAXONOMIC_SAMPLE_LEVEL=<<TAXONOMIC_SAMPLE_LEVELS>>"
    echo "## Will set TAXONOMIC_SAMPLE_LEVEL to default:"
    echo "## export TAXONOMIC_SAMPLE_LEVEL=("
    echo "##     \"D:domains\""
    echo "##     \"P:phylums\""
    echo "##     \"C:classes\""
    echo "##     \"O:orders\""
    echo "##     \"F:families\""
    echo "##     \"G:genuses\""
    echo "##     \"S:species\""
    echo "## )"
    echo "##**********************************"
    echo "##"
    export TAXONOMIC_SAMPLE_LEVEL=(
        "D:domains"
        "P:phylums"
        "C:classes"
        "O:orders"
        "F:families"
        "G:genuses"
        "S:species"
    )
else
    __all_taxas=$(echo "${TAXONOMIC_SAMPLE_LEVEL[@]}")
    echo "## TAXONOMIC_SAMPLE_LEVEL to analyse: $__all_taxas"
fi

if [[ -z "${TAXONOMIC_SAMPLE_BRACKEN_READ_LEN}" ]]; then
    echo "##**********************************"
    echo "## WARNING: TAXONOMIC_SAMPLE_BRACKEN_READ_LEN options is not defined. To set, edit config file: export TAXONOMIC_SAMPLE_BRACKEN_READ_LEN=<<option passed to TAXONOMIC_SAMPLE_BRACKEN_READ_LEN>>"
    echo "## Will set TAXONOMIC_SAMPLE_BRACKEN_READ_LEN to default 150"
    echo "##**********************************"
    echo "##"
    export TAXONOMIC_SAMPLE_BRACKEN_READ_LEN="150"
else
    echo "## TAXONOMIC_SAMPLE_BRACKEN_READ_LEN options: $TAXONOMIC_SAMPLE_BRACKEN_READ_LEN"
fi

if [[ -z "${TAXONOMIC_SAMPLE_SLURM_WALLTIME}" ]]; then
    echo "##**********************************"
    echo "## WARNING: TAXONOMIC_SAMPLE_SLURM_WALLTIME is not defined. To set, edit config file: export TAXONOMIC_SAMPLE_SLURM_WALLTIME=<<HH:MM:SS>>"
    echo "## Will set TAXONOMIC_SAMPLE_SLURM_WALLTIME to default TAXONOMIC_SAMPLE_SLURM_WALLTIME=24:00:00"
    echo "##**********************************"
    echo "##"
    export TAXONOMIC_SAMPLE_SLURM_WALLTIME="24:00:00"
else
    echo "## TAXONOMIC_SAMPLE_SLURM_WALLTIME: $TAXONOMIC_SAMPLE_SLURM_WALLTIME"
fi

if [[ -z "${TAXONOMIC_SAMPLE_SLURM_NBR_THREADS}" ]]; then
    echo "##**********************************"
    echo "## WARNING: TAXONOMIC_SAMPLE_SLURM_NBR_THREADS is not defined. To set, edit config file: export TAXONOMIC_SAMPLE_SLURM_NBR_THREADS=<<thread_nbr>>"
    echo "## Will set TAXONOMIC_SAMPLE_SLURM_NBR_THREADS to default TAXONOMIC_SAMPLE_SLURM_NBR_THREADS=24"
    echo "##**********************************"
    echo "##"
    export TAXONOMIC_SAMPLE_SLURM_NBR_THREADS=24
else
    echo "## TAXONOMIC_SAMPLE_SLURM_NBR_THREADS: $TAXONOMIC_SAMPLE_SLURM_NBR_THREADS"
fi

if [[ -z "${TAXONOMIC_SAMPLE_SLURM_MEMORY}" ]]; then
    echo "##**********************************"
    echo "## WARNING: TAXONOMIC_SAMPLE_SLURM_MEMORY is not defined. To set, edit config file: export TAXONOMIC_SAMPLE_SLURM_MEMORY=<<mem_in_G>>"
    echo "## Will set TAXONOMIC_SAMPLE_SLURM_MEMORY to default TAXONOMIC_SAMPLE_SLURM_MEMORY=125G"
    echo "##**********************************"
    echo "##"
    export TAXONOMIC_SAMPLE_SLURM_MEMORY="125G"
else
    echo "## TAXONOMIC_SAMPLE_SLURM_MEMORY: $TAXONOMIC_SAMPLE_SLURM_MEMORY"
fi


echo "################################################################################################################"

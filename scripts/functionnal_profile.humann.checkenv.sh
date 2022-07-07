#!/bin/bash

set -e

echo "################################################################################################################"

echo "## checking if all humann custom variables are properly defined"

if [[ -z "${FUNCPROFILING_SAMPLES_LIST_TSV}" ]]; then
    echo "## FATAL: FUNCPROFILING_SAMPLES_LIST_TSV variable must be defined. To set, edit config file: export FUNCPROFILING_SAMPLES_LIST_TSV=/path/to/sample.tsv"
    exit 1
elif [ ! -f "$FUNCPROFILING_SAMPLES_LIST_TSV" ]; then
    echo "## FATAL: $TAXONOMIC_SAMPLES_LIST_TSV file does not exist. Please specifiy a valid path. To set, edit config file: export FUNCPROFILING_SAMPLES_LIST_TSV=/path/to/sample.tsv"
    exit 1
fi
echo "## FUNCPROFILING_SAMPLES_LIST_TSV datapath: $FUNCPROFILING_SAMPLES_LIST_TSV"

if ! compgen -G "${FUNCPROFILING_NT_DB}.*.bt2l" > /dev/null
then

    echo "##**** FUNCPROFILING_NT_DB database index not found. ****"
    echo "## Please verify. An index file with the following name should be found: ${FUNCPROFILING_NT_DB}.1.bt2l"
    echo "##**********************************"
    echo "##"
    # exit 1
fi

if ! compgen -G  "${FUNCPROFILING_PROT_DB}/*.dmnd"  > /dev/null
then

    echo "##**** FUNCPROFILING_NT_DB database index not found. ****"
    echo "## Please verify. A diamond index file with the following name should be found: ${FUNCPROFILING_PROT_DB}/*.dmnd"
    echo "##**********************************"
    echo "##"
    exit 1
fi

if [[ -z "${FUNCPROFILING_SLURM_WALLTIME}" ]]; then
    echo "##**********************************"
    echo "## WARNING: FUNCPROFILING_SLURM_WALLTIME is not defined. To set, edit config file: export FUNCPROFILING_SLURM_WALLTIME=<<HH:MM:SS>>"
    echo "## Will set FUNCPROFILING_SLURM_WALLTIME to default FUNCPROFILING_SLURM_WALLTIME=24:00:00"
    echo "##**********************************"
    echo "##"
    export FUNCPROFILING_SLURM_WALLTIME="24:00:00"
else
    echo "## TAXONOMIC_SLURM_WALLTIME: $FUNCPROFILING_SLURM_WALLTIME"
fi

if [[ -z "${FUNCPROFILING_SLURM_NBR_THREADS}" ]]; then
    echo "##**********************************"
    echo "## WARNING: FUNCPROFILING_SLURM_NBR_THREADS is not defined. To set, edit config file: export FUNCPROFILING_SLURM_NBR_THREADS=<<thread_nbr>>"
    echo "## Will set FUNCPROFILING_SLURM_NBR_THREADS to default FUNCPROFILING_SLURM_NBR_THREADS=24"
    echo "##**********************************"
    echo "##"
    export FUNCPROFILING_SLURM_NBR_THREADS=24
else
    echo "## TAXONOMIC_SLURM_NBR_THREADS: $FUNCPROFILING_SLURM_NBR_THREADS"
fi

if [[ -z "${FUNCPROFILING_SLURM_MEMORY}" ]]; then
    echo "##**********************************"
    echo "## WARNING: FUNCPROFILING_SLURM_MEMORY is not defined. To set, edit config file: export FUNCPROFILING_SLURM_MEMORY=<<mem_in_G>>"
    echo "## Will set FUNCPROFILING_SLURM_MEMORY to default FUNCPROFILING_SLURM_MEMORY=30G"
    echo "##**********************************"
    echo "##"
    export FUNCPROFILING_SLURM_MEMORY="30G"
else
    echo "## TAXONOMIC_SLURM_MEMORY: $FUNCPROFILING_SLURM_MEMORY"
fi


echo "################################################################################################################"

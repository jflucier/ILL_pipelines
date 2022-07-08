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

case $FUNCPROFILING_SEARCH_MODE in

  "DUAL" | "NT" | "PROT")
    echo "## FUNCPROFILING_SEARCH_MODE: $FUNCPROFILING_SEARCH_MODE"
    ;;

  *)
    echo "##**** Unrecongnised FUNCPROFILING_SEARCH_MODE: $FUNCPROFILING_SEARCH_MODE ****"
    echo "## Possible modes are: DUAL, NT or PROT "
    echo "## Please edit configuration at this line: export FUNCPROFILING_SEARCH_MODE=\"DUAL\""
    echo "##**********************************"
    echo "##"
    # exit 1
    ;;
esac

if ! compgen -G "${FUNCPROFILING_NT_DB}.*.bt2l" > /dev/null
then

    echo "##**** FUNCPROFILING_NT_DB database index not found. ****"
    echo "## Please verify. An index file with the following name should be found: ${FUNCPROFILING_NT_DB}.1.bt2l"
    echo "##**********************************"
    echo "##"
    exit 1
fi

if ! compgen -G  "${FUNCPROFILING_PROT_DB}/*.dmnd"  > /dev/null
then

    echo "##**** FUNCPROFILING_NT_DB database index not found. ****"
    echo "## Please verify. A diamond index file with the following name should be found: ${FUNCPROFILING_PROT_DB}/*.dmnd"
    echo "##**********************************"
    echo "##"
    exit 1
fi

if [[ -z "${FUNCPROFILING_SLURM_BASE_WALLTIME}" ]]; then
    echo "##**********************************"
    echo "## WARNING: FUNCPROFILING_SLURM_BASE_WALLTIME is not defined. To set, edit config file: export FUNCPROFILING_SLURM_BASE_WALLTIME=<<HH:MM:SS>>"
    echo "## Will set FUNCPROFILING_SLURM_BASE_WALLTIME to default FUNCPROFILING_SLURM_BASE_WALLTIME=24:00:00"
    echo "##**********************************"
    echo "##"
    export FUNCPROFILING_SLURM_BASE_WALLTIME="24:00:00"
else
    echo "## FUNCPROFILING_SLURM_BASE_WALLTIME: $FUNCPROFILING_SLURM_BASE_WALLTIME"
fi

if [[ -z "${FUNCPROFILING_SLURM_BASE_NBR_THREADS}" ]]; then
    echo "##**********************************"
    echo "## WARNING: FUNCPROFILING_SLURM_BASE_NBR_THREADS is not defined. To set, edit config file: export FUNCPROFILING_SLURM_BASE_NBR_THREADS=<<thread_nbr>>"
    echo "## Will set FUNCPROFILING_SLURM_BASE_NBR_THREADS to default FUNCPROFILING_SLURM_BASE_NBR_THREADS=24"
    echo "##**********************************"
    echo "##"
    export FUNCPROFILING_SLURM_BASE_NBR_THREADS=24
else
    echo "## FUNCPROFILING_SLURM_BASE_NBR_THREADS: $FUNCPROFILING_SLURM_BASE_NBR_THREADS"
fi

if [[ -z "${FUNCPROFILING_SLURM_BASE_MEMORY}" ]]; then
    echo "##**********************************"
    echo "## WARNING: FUNCPROFILING_SLURM_BASE_MEMORY is not defined. To set, edit config file: export FUNCPROFILING_SLURM_BASE_MEMORY=<<mem_in_G>>"
    echo "## Will set FUNCPROFILING_SLURM_BASE_MEMORY to default FUNCPROFILING_SLURM_BASE_MEMORY=30G"
    echo "##**********************************"
    echo "##"
    export FUNCPROFILING_SLURM_BASE_MEMORY="30G"
else
    echo "## FUNCPROFILING_SLURM_BASE_MEMORY: $FUNCPROFILING_SLURM_BASE_MEMORY"
fi

if [[ -z "${FUNCPROFILING_SLURM_FAT_WALLTIME}" ]]; then
    echo "##**********************************"
    echo "## WARNING: FUNCPROFILING_SLURM_FAT_WALLTIME is not defined. To set, edit config file: export FUNCPROFILING_SLURM_FAT_WALLTIME=<<HH:MM:SS>>"
    echo "## Will set FUNCPROFILING_SLURM_FAT_WALLTIME to default FUNCPROFILING_SLURM_FAT_WALLTIME=24:00:00"
    echo "##**********************************"
    echo "##"
    export FUNCPROFILING_SLURM_FAT_WALLTIME="24:00:00"
else
    echo "## FUNCPROFILING_SLURM_FAT_WALLTIME: $FUNCPROFILING_SLURM_FAT_WALLTIME"
fi

if [[ -z "${FUNCPROFILING_SLURM_FAT_NBR_THREADS}" ]]; then
    echo "##**********************************"
    echo "## WARNING: FUNCPROFILING_SLURM_FAT_NBR_THREADS is not defined. To set, edit config file: export FUNCPROFILING_SLURM_FAT_NBR_THREADS=<<thread_nbr>>"
    echo "## Will set FUNCPROFILING_SLURM_FAT_NBR_THREADS to default FUNCPROFILING_SLURM_FAT_NBR_THREADS=24"
    echo "##**********************************"
    echo "##"
    export FUNCPROFILING_SLURM_FAT_NBR_THREADS=24
else
    echo "## FUNCPROFILING_SLURM_FAT_NBR_THREADS: $FUNCPROFILING_SLURM_FAT_NBR_THREADS"
fi

if [[ -z "${FUNCPROFILING_SLURM_FAT_MEMORY}" ]]; then
    echo "##**********************************"
    echo "## WARNING: FUNCPROFILING_SLURM_FAT_MEMORY is not defined. To set, edit config file: export FUNCPROFILING_SLURM_FAT_MEMORY=<<mem_in_G>>"
    echo "## Will set FUNCPROFILING_SLURM_FAT_MEMORY to default FUNCPROFILING_SLURM_FAT_MEMORY=30G"
    echo "##**********************************"
    echo "##"
    export FUNCPROFILING_SLURM_FAT_MEMORY="125G"
else
    echo "## FUNCPROFILING_SLURM_FAT_MEMORY: $FUNCPROFILING_SLURM_FAT_MEMORY"
fi


echo "################################################################################################################"

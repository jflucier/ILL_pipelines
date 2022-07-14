#!/bin/bash

set -e

echo "################################################################################################################"

echo "## checking if all humann custom variables are properly defined"


if [ ! -d "${TAXONOMIC_ALL_CHOCOPHLAN_DB}" ]
then

    echo "##**** CHOCOPHLAN database directory not found. ****"
    echo "## Please verify. The path should be found with multiple *.ffn.gz files inside"
    echo "##**********************************"
    echo "##"
    exit 1
fi

if [[ -z "${TAXONOMIC_ALL_LEVEL}" ]]; then
    echo "##**********************************"
    echo "## WARNING: TAXONOMIC_LEVEL option is not defined. To set, edit config file: export TAXONOMIC_LEVEL=<<TAXONOMIC_LEVELS>>"
    echo "## Will set TAXONOMIC_LEVEL to default:"
    echo "## export TAXONOMIC_LEVEL=("
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
    export TAXONOMIC_ALL_LEVEL=(
        "D:domains"
        "P:phylums"
        "C:classes"
        "O:orders"
        "F:families"
        "G:genuses"
        "S:species"
    )
else
    __all_taxas=$(echo "${TAXONOMIC_ALL_LEVEL[@]}")
    echo "## TAXONOMIC_LEVEL to analyse: $__all_taxas"
fi

if [[ -z "${TAXONOMIC_ALL_NT_DBNAME}" ]]; then
    echo "##**********************************"
    echo "## WARNING: TAXONOMIC_ALL_NT_DBNAME is not defined. To set, edit config file: export TAXONOMIC_ALL_NT_DBNAME=<<ntdb_name>>"
    echo "## Will set TAXONOMIC_ALL_NT_DBNAME to default TAXONOMIC_ALL_NT_DBNAME=my_ntdb"
    echo "##**********************************"
    echo "##"
    export TAXONOMIC_ALL_NT_DBNAME="my_ntdb"
else
    echo "## TAXONOMIC_ALL_NT_DBNAME: $TAXONOMIC_ALL_NT_DBNAME"
fi

if [[ -z "${TAXONOMIC_ALL_BRACKEN_KREPORTS}" ]]; then
    echo "##**********************************"
    echo "## WARNING: TAXONOMIC_ALL_BRACKEN_KREPORTS is not defined. To set, edit config file: export TAXONOMIC_ALL_BRACKEN_KREPORTS=<<bracken_reports>>"
    echo "## Will set TAXONOMIC_ALL_BRACKEN_KREPORTS to default TAXONOMIC_ALL_BRACKEN_KREPORTS=$OUTPUT_PATH/taxonomic_profile/*/*_bracken/*_bracken_S.kreport"
    echo "##**********************************"
    echo "##"
    export TAXONOMIC_ALL_BRACKEN_KREPORTS="$OUTPUT_PATH/taxonomic_profile/*/*_bracken/*_bracken_S.kreport"
else
    echo "## TAXONOMIC_ALL_BRACKEN_KREPORTS: $TAXONOMIC_ALL_BRACKEN_KREPORTS"
fi

if [[ -z "${TAXONOMIC_ALL_SLURM_WALLTIME}" ]]; then
    echo "##**********************************"
    echo "## WARNING: TAXONOMIC_ALL_SLURM_WALLTIME is not defined. To set, edit config file: export TAXONOMIC_ALL_SLURM_WALLTIME=<<HH:MM:SS>>"
    echo "## Will set TAXONOMIC_ALL_SLURM_WALLTIME to default TAXONOMIC_ALL_SLURM_WALLTIME=24:00:00"
    echo "##**********************************"
    echo "##"
    export TAXONOMIC_ALL_SLURM_WALLTIME="24:00:00"
else
    echo "## TAXONOMIC_ALL_SLURM_WALLTIME: $TAXONOMIC_ALL_SLURM_WALLTIME"
fi

if [[ -z "${TAXONOMIC_ALL_SLURM_NBR_THREADS}" ]]; then
    echo "##**********************************"
    echo "## WARNING: TAXONOMIC_ALL_SLURM_NBR_THREADS is not defined. To set, edit config file: export TAXONOMIC_ALL_SLURM_NBR_THREADS=<<thread_nbr>>"
    echo "## Will set TAXONOMIC_ALL_SLURM_NBR_THREADS to default TAXONOMIC_ALL_SLURM_NBR_THREADS=24"
    echo "##**********************************"
    echo "##"
    export TAXONOMIC_ALL_SLURM_NBR_THREADS=24
else
    echo "## TAXONOMIC_ALL_SLURM_NBR_THREADS: $TAXONOMIC_ALL_SLURM_NBR_THREADS"
fi

if [[ -z "${TAXONOMIC_ALL_SLURM_MEMORY}" ]]; then
    echo "##**********************************"
    echo "## WARNING: TAXONOMIC_ALL_SLURM_MEMORY is not defined. To set, edit config file: export TAXONOMIC_ALL_SLURM_MEMORY=<<mem_in_G>>"
    echo "## Will set TAXONOMIC_ALL_SLURM_MEMORY to default TAXONOMIC_ALL_SLURM_MEMORY=125G"
    echo "##**********************************"
    echo "##"
    export TAXONOMIC_ALL_SLURM_MEMORY="125G"
else
    echo "## TAXONOMIC_ALL_SLURM_MEMORY: $TAXONOMIC_ALL_SLURM_MEMORY"
fi


echo "################################################################################################################"

#!/bin/bash

set -e

echo "################################################################################################################"

echo "## checking if all humann custom variables are properly defined"

if [[ -z "${ASSEMBLY_SAMPLE_F1_PATH_REGEX}" ]]; then
    echo "##**********************************"
    echo "## FAIL: ASSEMBLY_SAMPLE_F1_PATH_REGEX is not defined. To set, edit config file: export ASSEMBLY_SAMPLE_F1_PATH_REGEX=<<regex for valid forward fastq path>>"
    echo "##**********************************"
    echo "##"
    exit 1
fi

if [[ -z "${ASSEMBLY_SAMPLE_F2_PATH_REGEX}" ]]; then
    echo "##**********************************"
    echo "## FAIL: ASSEMBLY_SAMPLE_F2_PATH_REGEX is not defined. To set, edit config file: export ASSEMBLY_SAMPLE_F2_PATH_REGEX=<<regex for valid reverse fastq path>>"
    echo "##**********************************"
    echo "##"
    exit 1
fi

if [[ -z "${ASSEMBLY_BIN_REFINEMENT_MIN_COMPLETION}" ]]; then
    echo "##**********************************"
    echo "## WARNING: ASSEMBLY_BIN_REFINEMENT_MIN_COMPLETION is not defined. To set, edit config file: export ASSEMBLY_BIN_REFINEMENT_MIN_COMPLETION=<<bin_min_completion>>"
    echo "## See https://github.com/bxlab/metaWRAP/blob/master/Usage_tutorial.md for more information"
    echo "## Will set ASSEMBLY_BIN_REFINEMENT_MIN_COMPLETION to default ASSEMBLY_BIN_REFINEMENT_MIN_COMPLETION=50"
    echo "##**********************************"
    echo "##"
    export ASSEMBLY_BIN_REFINEMENT_MIN_COMPLETION=50
else
    echo "## ASSEMBLY_BIN_REFINEMENT_MIN_COMPLETION: $ASSEMBLY_BIN_REFINEMENT_MIN_COMPLETION"
fi

if [[ -z "${ASSEMBLY_BIN_REFINEMENT_MAX_CONTAMINATION}" ]]; then
    echo "##**********************************"
    echo "## WARNING: ASSEMBLY_BIN_REFINEMENT_MAX_CONTAMINATION is not defined. To set, edit config file: export ASSEMBLY_BIN_REFINEMENT_MAX_CONTAMINATION=<<max percent contamine>>"
    echo "## See https://github.com/bxlab/metaWRAP/blob/master/Usage_tutorial.md for more information"
    echo "## Will set ASSEMBLY_BIN_REFINEMENT_MAX_CONTAMINATION to default ASSEMBLY_BIN_REFINEMENT_MAX_CONTAMINATION=10"
    echo "##**********************************"
    echo "##"
    export ASSEMBLY_BIN_REFINEMENT_MAX_CONTAMINATION=10
else
    echo "## ASSEMBLY_BIN_REFINEMENT_MIN_COMPLETION: $ASSEMBLY_BIN_REFINEMENT_MIN_COMPLETION"
fi


if [[ -z "${ASSEMBLY_SLURM_WALLTIME}" ]]; then
    echo "##**********************************"
    echo "## WARNING: ASSEMBLY_SLURM_WALLTIME is not defined. To set, edit config file: export ASSEMBLY_SLURM_WALLTIME=<<estimated_time>>"
    echo "## Will set ASSEMBLY_SLURM_WALLTIME to default ASSEMBLY_SLURM_WALLTIME=24:00:00"
    echo "##**********************************"
    echo "##"
    export ASSEMBLY_SLURM_WALLTIME="24:00:00"
else
    echo "## ASSEMBLY_SLURM_WALLTIME: $ASSEMBLY_SLURM_WALLTIME"
fi

if [[ -z "${ASSEMBLY_SLURM_NBR_THREADS}" ]]; then
    echo "##**********************************"
    echo "## WARNING: ASSEMBLY_SLURM_NBR_THREADS is not defined. To set, edit config file: export ASSEMBLY_SLURM_NBR_THREADS=<<nbr_of_threads>>"
    echo "## Will set ASSEMBLY_SLURM_NBR_THREADS to default ASSEMBLY_SLURM_NBR_THREADS=24"
    echo "##**********************************"
    echo "##"
    export ASSEMBLY_SLURM_NBR_THREADS="24"
else
    echo "## TAXONOMIC_SLURM_MEMORY: $ASSEMBLY_SLURM_NBR_THREADS"
fi

if [[ -z "${ASSEMBLY_SLURM_MEMORY}" ]]; then
    echo "##**********************************"
    echo "## WARNING: ASSEMBLY_SLURM_MEMORY is not defined. To set, edit config file: export ASSEMBLY_SLURM_MEMORY=<<mem_in_G>>"
    echo "## Will set ASSEMBLY_SLURM_MEMORY to default ASSEMBLY_SLURM_MEMORY=30G"
    echo "##**********************************"
    echo "##"
    export ASSEMBLY_SLURM_MEMORY="30G"
else
    echo "## ASSEMBLY_SLURM_MEMORY: $ASSEMBLY_SLURM_MEMORY"
fi


echo "################################################################################################################"

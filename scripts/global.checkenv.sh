#!/bin/bash

set -e

echo "################################################################################################################"

echo "## Checking global software dependencies"

echo "## checking if all humann custom variables are properly defined"

if [ ! -d "${OUPUT_PATH}" ]
then
    echo "##**********************************"
    echo "## Output directory ${OUPUT_PATH} does not exists. Will try to create it."
    mkdir -p  ${OUPUT_PATH}
    echo "## Output directory ${OUPUT_PATH} was created"
    echo "##**********************************"
    echo "##"
fi

if [[ -z "${SLURM_ALLOCATION}" ]]; then
    echo "##**********************************"
    echo "## WARNING: SLURM_ALLOCATION is not defined. To set, edit config file: export SLURM_ALLOCATION=<<slurm_account_name>>"
    echo "## Will set SLURM_ALLOCATION to to empty string. Make sure you modify cnau slurm script if you plan to use!"
    echo "##**********************************"
    echo "##"
    export SLURM_ALLOCATION=""
else
    echo "## SLURM_ALLOCATION: $SLURM_ALLOCATION"
fi

if [[ -z "${SLURM_DB_COPY_LOCALSCRATCH}" ]]; then
    echo "##**********************************"
    echo "## WARNING: SLURM_DB_COPY_LOCALSCRATCH is not defined. To set, edit config file: export SLURM_DB_COPY_LOCALSCRATCH=<<0 or 1>>"
    echo "## Will set SLURM_DB_COPY_LOCALSCRATCH to default SLURM_DB_COPY_LOCALSCRATCH=0 to desactivate database copy on compute node localscratch"
    echo "##**********************************"
    echo "##"
    export SLURM_DB_COPY_LOCALSCRATCH=0
else
    echo "## SLURM_DB_COPY_LOCALSCRATCH: $SLURM_DB_COPY_LOCALSCRATCH"
fi

echo "################################################################################################################"

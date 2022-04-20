#!/bin/bash

set -e

echo "################################################################################################################"

echo "## Checking global software dependencies"

# if ! command -v "bowtie2" &> /dev/null
# then
#     echo "##**** bowtie2 could not be found ****"
#     echo "## Please install bowtie2 and and put in PATH variable"
#     echo "## export PATH=/path/to/bowtie2:\$PATH"
#     echo "##**********************************"
#     echo "##"
#     exit 1
# fi
#
# if ! command -v "samtools" &> /dev/null
# then
#     echo "##**** samtools could not be found ****"
#     echo "## Please install samtools and and put in PATH variable"
#     echo "## export PATH=/path/to/samtools:\$PATH"
#     echo "##**********************************"
#     echo "##"
#     exit 1
# fi

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

if [[ -z "${SLURM_WALLTIME}" ]]; then
    echo "##**********************************"
    echo "## WARNING: SLURM_WALLTIME is not defined. To set, edit config file: export SLURM_WALLTIME=<<HH:MM:SS>>"
    echo "## Will set SLURM_WALLTIME to default SLURM_WALLTIME=35:00:00"
    echo "##**********************************"
    echo "##"
    export SLURM_WALLTIME="35:00:00"
else
    echo "## SLURM_WALLTIME: $SLURM_WALLTIME"
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

if [[ -z "${SLURM_NBR_THREADS}" ]]; then
    echo "##**********************************"
    echo "## WARNING: SLURM_NBR_THREADS is not defined. To set, edit config file: export SLURM_NBR_THREADS=<<thread_nbr>>"
    echo "## Will set SLURM_NBR_THREADS to default SLURM_NBR_THREADS=24"
    echo "##**********************************"
    echo "##"
    export SLURM_NBR_THREADS=24
else
    echo "## SLURM_NBR_THREADS: $SLURM_NBR_THREADS"
fi

if [[ -z "${SLURM_MEMORY}" ]]; then
    echo "##**********************************"
    echo "## WARNING: SLURM_MEMORY is not defined. To set, edit config file: export SLURM_MEMORY=<<mem_in_G>>"
    echo "## Will set SLURM_MEMORY to default SLURM_MEMORY=125G"
    echo "##**********************************"
    echo "##"
    export SLURM_MEMORY="125G"
else
    echo "## SLURM_MEMORY: $SLURM_MEMORY"
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

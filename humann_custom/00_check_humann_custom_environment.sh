#!/bin/bash

set -e

echo "################################################################################################################"

echo "## Checking humann software dependencies"

# if ! command -v "diamond" &> /dev/null
# then
#     echo "##**** diamond could not be found ****"
#     echo "## Please install diamond and and put in PATH variable"
#     echo "## export PATH=/path/to/diamond:\$PATH"
#     echo "##**********************************"
#     echo "##"
#     exit 1
# fi
#
# if ! command -v "humann" &> /dev/null
# then
#     echo "##**** humann could not be found ****"
#     echo "## Please install humann and and put in PATH variable"
#     echo "## export PATH=/path/to/humann:\$PATH"
#     echo "##**********************************"
#     echo "##"
#     exit 1
# fi

echo "## checking if all humann custom variables are properly defined"

if [ ! -f "${NT_DB}.1.bt2l" ]
then

    echo "##**** Bowtie2 nucleotide db index not found. ****"
    echo "## Please verify. An index file with the following name should be found: ${NT_DB}.1.bt2l"
    echo "##**********************************"
    echo "##"
    exit 1
fi

if [ ! -f ${PROT_DB}/*.dmnd ]
then

    echo "##**** Protein database not found. ****"
    echo "## Please verify. A a diamond file index (*.dmnd) should be found in: ${PROT_DB}"
    echo "##**********************************"
    echo "##"
    exit 1
fi

if [[ -z "${HUMANN_RUN_SAMPLE_TSV}" ]]; then
    echo "## FATAL: HUMANN_RUN_SAMPLE_TSV variable must be defined. To set, edit config file: export HUMANN_RUN_SAMPLE_TSV=/path/to/sample.tsv"
    exit 1
elif [ ! -f "$HUMANN_RUN_SAMPLE_TSV" ]; then
    echo "## FATAL: $HUMANN_RUN_SAMPLE_TSV file does not exist. Please specifiy a valid path. To set, edit config file: export HUMANN_RUN_SAMPLE_TSV=/path/to/sample.tsv"
    exit 1
fi
echo "## SAMPLE_TSV datapath: $HUMANN_RUN_SAMPLE_TSV"


echo "################################################################################################################"

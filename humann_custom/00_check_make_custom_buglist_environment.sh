#!/bin/bash

set -e

echo "################################################################################################################"

echo "## checking if all humann custom variables are properly defined"

if [[ -z "${CUSTOM_DB_SAMPLE_TSV}" ]]; then
    echo "## FATAL: SAMPLE_TSV variable must be defined. To set, edit config file: export CUSTOM_DB_SAMPLE_TSV=/path/to/sample.tsv"
    exit 1
elif [ ! -f "$CUSTOM_DB_SAMPLE_TSV" ]; then
    echo "## FATAL: $CUSTOM_DB_SAMPLE_TSV file does not exist. Please specifiy a valid path. To set, edit config file: export CUSTOM_DB_SAMPLE_TSV=/path/to/sample.tsv"
    exit 1
fi
echo "## SAMPLE_TSV datapath: $CUSTOM_DB_SAMPLE_TSV"

if [ ! -f "${KNEADDATA_DB}.1.bt2" ]
then

    echo "##**** KNEADDATA Bowtie2 db index not found. ****"
    echo "## Please verify. An index file with the following name should be found: ${KNEADDATA_DB}.1.bt2"
    echo "##**********************************"
    echo "##"
    exit 1
fi

if [[ -z "${KRAKEN2_DB_PATH}" ]]; then
    echo "## FATAL: KRAKEN2_DB_PATH variable must be defined. To set, edit config file: export KRAKEN2_DB_PATH=/path/to/krakendb"
    exit 1
elif [ ! -d "$KRAKEN2_DB_PATH" ]; then
    echo "## FATAL: $KRAKEN2_DB_PATH directory does not exist. Please specifiy a valid path. To set, edit config file: export KRAKEN2_DB_PATH=/path/to/krakendb"
    exit 1
fi
echo "## KRAKEN2 DB PATH: $KRAKEN2_DB_PATH"

if [[ -z "${SEQUENCER}" ]]; then
    echo "##**********************************"
    echo "## WARNING: KNEADDATA SEQUENCER option is not defined. To set, edit config file: export SEQUENCER=<<sequencer type>>"
    echo "## Will set SEQUENCER to default TruSeq3"
    echo "##**********************************"
    echo "##"
    export SEQUENCER="TruSeq3"
else
    echo "## SEQUENCER: $SEQUENCER"
fi

if [[ -z "${TRIMMOMATIC}" ]]; then
    echo "##**********************************"
    echo "## WARNING: TRIMMOMATIC options is not defined. To set, edit config file: export TRIMMOMATIC=<<option passed to trimmomatic>>"
    echo "## Will set TRIMMOMATIC to default MINLEN:50 SLIDINGWINDOW:4:30"
    echo "##**********************************"
    echo "##"
    export TRIMMOMATIC="MINLEN:50 SLIDINGWINDOW:4:30"
else
    echo "## TRIMMOMATIC options: $TRIMMOMATIC"
fi

if [[ -z "${BOWTIE2_OPTIONS}" ]]; then
    echo "##**********************************"
    echo "## WARNING: BOWTIE2_OPTIONS options is not defined. To set, edit config file: export BOWTIE2_OPTIONS=<<option passed to bowtie2>>"
    echo "## Will set BOWTIE2_OPTIONS to default --very-sensitive"
    echo "##**********************************"
    echo "##"
    export BOWTIE2_OPTIONS="--very-sensitive"
else
    echo "## BOWTIE2_OPTIONS options: $BOWTIE2_OPTIONS"
fi


if [[ -z "${READ_LEN}" ]]; then
    echo "##**********************************"
    echo "## WARNING: BRACKEN READ_LEN options is not defined. To set, edit config file: export READ_LEN=<<read length>>"
    echo "## Will set BRACKEN READ_LEN to default 150nt"
    echo "##**********************************"
    echo "##"
    export READ_LEN="150"
else
    echo "## BRACKEN READ_LEN options: $READ_LEN"
fi


echo "################################################################################################################"

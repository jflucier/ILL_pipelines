#!/bin/bash

set -e

echo "load and valdiate env"
# load and valdiate env
export EXE_PATH=$(dirname "$0")

if [ -z ${1+x} ]; then
    echo "Please provide a configuration file. See ${EXE_PATH}/my.example.config for an example."
    exit 1
fi

source $1
${EXE_PATH}/00_check_global_environment.sh
${EXE_PATH}/00_check_humann_custom_environment.sh

echo "outputting humann custom slurm script to ${OUPUT_PATH}/custom_human.slurm.sh"

echo '#!/bin/bash' > ${OUPUT_PATH}/custom_human.slurm.sh
echo '
#SBATCH --mail-type=END,FAIL
#SBATCH -D '${OUPUT_PATH}'
#SBATCH -o '${OUPUT_PATH}'/custom_humann-%A_%a.slurm.out
#SBATCH --time='${SLURM_WALLTIME}'
#SBATCH --mem='${SLURM_MEMORY}'
#SBATCH -N 1
#SBATCH -n '${SLURM_NBR_THREADS}'
#SBATCH -A '${SLURM_ALLOCATION}'
#SBATCH -J humann

newgrp def-ilafores
echo "loading env"
export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6
module use $MUGQIC_INSTALL_HOME/modulefiles

module load StdEnv/2020 gcc/9 python/3.7.9 java/14.0.2 mugqic/bowtie2/2.3.5 mugqic/samtools/1.14 mugqic/usearch/10.0.240
source /project/def-ilafores/common/humann3/bin/activate
export PATH=/nfs3_ib/ip29-ib/ip29/ilafores_group/programs/diamond-2.0.14/bin:$PATH

export __sample_line=$(cat '${SAMPLE_TSV}' | awk "NR==$SLURM_ARRAY_TASK_ID")
export __sample=$(echo -e "$__sample_line" | cut -d$'"'"'\t'"'"' -f1)
export __fastq=$(echo -e "$__sample_line" | cut -d$'"'"'\t'"'"' -f2)
export __fastq_file=$(basename $__fastq)

echo "copying fastq $__fastq"
cp $__fastq $SLURM_TMPDIR/${__fastq_file}
' >> ${OUPUT_PATH}/custom_human.slurm.sh

if [[ "$SLURM_DB_COPY_LOCALSCRATCH" -eq "0" ]]
then
echo '
export __NT_DB='${NT_DB}'
export __PROT_DB='${PROT_DB}'
' >> ${OUPUT_PATH}/custom_human.slurm.sh
else
echo '
mkdir $SLURM_TMPDIR/db
echo "copying nucleotide bowtie index '${NT_DB}'"
export __NT_DB_BT2=$(basename '${NT_DB}')
cp '${NT_DB}'*.bt2l $SLURM_TMPDIR/db/

echo "copying protein diamond index '${PROT_DB}'"
export __PROT_DIA_IDX=$(basename '${PROT_DB}')
cp -r '${PROT_DB}' $SLURM_TMPDIR/db

export __NT_DB=$SLURM_TMPDIR/db/${__NT_DB_BT2}
export __PROT_DB=$SLURM_TMPDIR/db/${__PROT_DIA_IDX}
' >> ${OUPUT_PATH}/custom_human.slurm.sh
fi

echo '
echo "running humann"
mkdir -p $SLURM_TMPDIR/${__sample}
echo "outputting to $SLURM_TMPDIR/${__sample}"
humann \
-v --threads '${SLURM_NBR_THREADS}' \
--o-log '${OUPUT_PATH}'/custom_humann-${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.humann.out \
--input $SLURM_TMPDIR/${__fastq_file} \
--output $SLURM_TMPDIR/${__sample} --output-basename ${__sample} \
--nucleotide-database $__NT_DB \
--protein-database $__PROT_DB \
--bypass-prescreen --bypass-nucleotide-index

rm -f $SLURM_TMPDIR/${__sample}/*cpm*
rm -f $SLURM_TMPDIR/${__sample}/*relab*
for norm_method in cpm relab;
do
	if [[ $norm_method == "cpm" ]]; then
		echo "...normalizing abundances as copies per millions"
	else
		echo "...normalizing abundances as relative abundance"
	fi

	humann_renorm_table \
    --input $SLURM_TMPDIR/${__sample}/*_genefamilies.tsv \
	--output $SLURM_TMPDIR/${__sample}/${__sample}_genefamilies-${norm_method}.tsv \
    --units ${norm_method} --update-snames

	for uniref_db in uniref90_rxn uniref90_go uniref90_ko uniref90_level4ec uniref90_pfam uniref90_eggnog;
    do
		if [[ $uniref_db == *"rxn"* ]]; then
			__NAMES=metacyc-rxn
            __MAP=mc-rxn
		elif [[ $uniref_db == *"ko"* ]]; then
			__NAMES=kegg-orthology
            __MAP=kegg
		elif [[ $uniref_db == *"level4ec"* ]]; then
			__NAMES=ec
            __MAP=level4ec
		else
			__NAMES=${uniref_db/uniref90_/}
            __MAP=$__NAMES
		fi

		echo "...regrouping genes to $__NAMES reactions"
		humann_regroup_table \
        --input $SLURM_TMPDIR/${__sample}/${__sample}_genefamilies-${norm_method}.tsv \
		--output $SLURM_TMPDIR/${__sample}/${__sample}_genefamilies-${norm_method}_${__MAP}.tsv \
        --groups ${uniref_db}

		echo  "...attaching names to $__MAP codes" ## For convenience
		humann_rename_table \
        --input $SLURM_TMPDIR/${__sample}/${__sample}_genefamilies-${norm_method}_${__MAP}.tsv \
		--output $SLURM_TMPDIR/${__sample}/${__sample}_genefamilies-${norm_method}_${__MAP}_named.tsv \
        --names $__NAMES
	done
done

echo "...creating community-level profiles"
rm -fr $SLURM_TMPDIR/${__sample}/${__sample}_community_tables/*
mkdir -p $SLURM_TMPDIR/${__sample}/${__sample}_community_tables
for f in $SLURM_TMPDIR/${__sample}/*.tsv
do
    b=$(basename $f)
	grep -v "|" ${f} > $SLURM_TMPDIR/${__sample}/${__sample}_community_tables/${b//.tsv/}_community.tsv
done


echo "copying results to '${OUPUT_PATH}'/${__sample}"
cp -r $SLURM_TMPDIR/${__sample} '${OUPUT_PATH}'

echo "done"
' >> ${OUPUT_PATH}/custom_human.slurm.sh

echo "To submit to slurm, execute the following command:"
read sample_nbr f <<< $(wc -l ${SAMPLE_TSV})
echo "sbatch --array=1-$sample_nbr ${OUPUT_PATH}/custom_human.slurm.sh"
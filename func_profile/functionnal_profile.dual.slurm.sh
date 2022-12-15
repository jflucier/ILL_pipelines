#!/bin/bash

#SBATCH --mail-type=END,FAIL
#SBATCH -D /nfs3_ib/ip29-ib/ip29/ilafores_group/projet_PROVID19/ILL_pipelines/func_profile
#SBATCH -o /nfs3_ib/ip29-ib/ip29/ilafores_group/projet_PROVID19/ILL_pipelines/func_profile/logs/functionnal_profile-%A_%a.slurm.out
#SBATCH --time=72:00:00
#SBATCH --mem=31G
#SBATCH -N 1
#SBATCH -n 24
#SBATCH -A def-ilafores
#SBATCH -J functionnal_profile


#SBATCH --mail-user=ronj2303@usherbrooke.ca



newgrp def-ilafores
echo "loading env"
export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6
module use $MUGQIC_INSTALL_HOME/modulefiles

module load StdEnv/2020 gcc/9 python/3.7.9 java/14.0.2 mugqic/bowtie2/2.3.5 mugqic/samtools/1.14 mugqic/usearch/10.0.240
export __sample_line=$(cat /nfs3_ib/ip29-ib/ip29/ilafores_group/projet_PROVID19/ILL_pipelines/preproc_60/preprocessed_reads.sample.tsv | awk "NR==$SLURM_ARRAY_TASK_ID")
export __sample=$(echo -e "$__sample_line" | cut -f1)
export __fastq_file1=$(echo -e "$__sample_line" | cut -f2)
export __fastq_file2=$(echo -e "$__sample_line" | cut -f3)

bash /nfs3_ib/ip29-ib/ip29/ilafores_group/projet_PROVID19/ILL_pipelines/scripts/functionnal_profile.humann.sh \
-o /nfs3_ib/ip29-ib/ip29/ilafores_group/projet_PROVID19/ILL_pipelines/func_profile/dual/$__sample \
-tmp $SLURM_TMPDIR \
-t 24 -m 31G \
-s $__sample \
-fq1 $__fastq_file1 \
-fq2 $__fastq_file2 \
--search_mode dual \
--nt_db /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/humann_dbs/provid19/ \
--prot_db /project/def-ilafores/common/humann3/lib/python3.7/site-packages/humann/data/uniref \
--log /nfs3_ib/ip29-ib/ip29/ilafores_group/projet_PROVID19/ILL_pipelines/func_profile/logs/humann_${__sample}.log



#!/bin/bash
#SBATCH --mail-type=END,FAIL
#SBATCH -D /nfs3_ib/nfs-ip34//home/def-ilafores/programs/ILL_pipelines/containers
#SBATCH -o /nfs3_ib/nfs-ip34//home/def-ilafores/programs/ILL_pipelines/containers/test-%A_%a.slurm.out
#SBATCH --time=00:01:00
#SBATCH --mem=1G
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -A def-jflucier
#SBATCH -J test


ml apptainer

singularity exec -e checkm2.1.0.2.sif checkm2




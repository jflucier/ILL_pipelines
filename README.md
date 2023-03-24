# ILL Humann custom pipeline User Manual

----

## Contents ##

* [Requirements](#requirements)
* [Installation](#installation)
* [How to run](#how-to-run)
    * [Run preprocess kneaddata](#Run-preprocess-kneaddata)
    * [Run Kraken2 taxonomic profile per sample](#Run-Kraken2-taxonomic-profile-per-sample)
    * [Generate taxonomy table on all samples for a specific taxonomic level](#Generate-taxonomy-table-on-all-samples-for-a-specific-taxonomic-level)
    * [Generate HUMAnN bugs list](#Generate-HUMAnN-bugs-list)
    * [Run HUMAnN functionnal profile](#Run-HUMAnN-functionnal-profile)
    * [Run MetaWRAP assembly, binning and bin refinement](#Run-MetaWRAP-assembly,-binning-and-bin-refinement)

----

## Requirements ##

All pipelines are self contained. The only requirements needed is [Apptainer](https://apptainer.org/). The apptainer executable "singularity" should be available in your path.

**Note**: On interactive node include the ``module load StdEnv/2020 apptainer/1.1.5 `` in your ~/.bashrc file

----

## Installation ##

To install ILL pipelines you need to:

* Create a clone of the repository:

    ``git clone https://github.com/jflucier/ILL_pipelines.git ``

    Note: Creating a clone of the repository requires [Github](https://github.com/) to be installed.

* For convenience, set environment variable ILL_PIPELINES in your ~/.bashrc:

    ``export ILL_PIPELINES=/path/to/ILL_pipelines ``

    Note: On ip34, ILL pipelines path is /home/def-ilafores/programs/ILL_pipelines

* Go to $ILL_PIPELINES/containers and run these commands:
```
module load StdEnv/2020 apptainer/1.1.5
cd $ILL_PIPELINES/containers
sh build_all.sh

```


----

## How to run ##

To run pipelines you need to create a sample spread with 3 columns like this table:

|           |                               |                               |
|-----------|-------------------------------|-------------------------------|
| sample1 	| /path/to/sample1.R1.fastq 	| /path/to/sample1.R2.fastq 	|
| sample2 	| /path/to/sample2.R1.fastq 	| /path/to/sample2.R2.fastq 	|
| etc...  	| etc...                    	| etc...                    	|

**Important note: TSV files must not have header line.**

### Run preprocess kneaddata ###

For full list of options:

```
$ bash $ILL_PIPELINES/generateslurm_preprocess.kneaddata.sh -h

Usage: generateslurm_preprocess.kneaddata.sh --sample_tsv /path/to/tsv --out /path/to/out [--db] [--trimmomatic_options "trim options"] [--bowtie2_options "bowtie2 options"]
Options:

	--sample_tsv STR	path to sample tsv (3 columns: sample name<tab>fastq1 path<tab>fastq2 path)
	--out STR	path to output dir
	--db	kneaddata database path (default /net/nfs-ip34/fast/def-ilafores/host_genomes/GRCh38_index/grch38_1kgmaj)
	--trimmomatic_options	options to pass to trimmomatic (default ILLUMINACLIP:/cvmfs/soft.mugqic/CentOS6/software/trimmomatic/Trimmomatic-0.39/adapters/TruSeq3-PE-2.fa:2:30:10 SLIDINGWINDOW:4:30 MINLEN:100)
	--bowtie2_options	options to pass to trimmomatic (default --very-sensitive-local)

Slurm options:
	--slurm_alloc STR	slurm allocation (default def-ilafores)
	--slurm_log STR	slurm log file output directory (default to output_dir/logs)
	--slurm_email "your@email.com"	Slurm email setting
	--slurm_walltime STR	slurm requested walltime (default 24:00:00)
	--slurm_threads INT	slurm requested number of threads (default 24)
	--slurm_mem STR	slurm requested memory (default 30)

  -h --help	Display help

```

Most default values should be ok on ip34. Make sure you specify sample_tsv, output path.

Here is how generate slurm script with default parameters:
```

$> bash $ILL_PIPELINES/generateslurm_preprocess.kneaddata.sh \
> --sample_tsv /net/nfs-ip34/home/def-ilafores/analysis/20230216_metagenome_test/data/testset-projet_PROVID19/saliva_samples/sample_provid19.saliva.test.tsv \
> --out /net/nfs-ip34/home/def-ilafores/analysis/20230216_metagenome_test/testset-projet_PROVID19-saliva/preprocess \
> --db /cvmfs/datahub.genap.ca/vhost34/def-ilafores/host_genomes/GRCh38_index/grch38_1kgmaj \
> --slurm_email "your_email@domain.ca" \
> --bowtie2_options "--very-sensitive" \
> --slurm_walltime "6:00:00"
## Will use sample file: /net/nfs-ip34/home/def-ilafores/analysis/20230216_metagenome_test/data/testset-projet_PROVID19/saliva_samples/sample_provid19.saliva.test.tsv
## Results wil be stored to this path: /net/nfs-ip34/home/def-ilafores/analysis/20230216_metagenome_test/testset-projet_PROVID19-saliva/preprocess
## Will output logs in: /net/nfs-ip34/home/def-ilafores/analysis/20230216_metagenome_test/testset-projet_PROVID19-saliva/preprocess/logs
outputting preprocess slurm script to /net/nfs-ip34/home/def-ilafores/analysis/20230216_metagenome_test/testset-projet_PROVID19-saliva/preprocess/preprocess.kneaddata.slurm.sh
Generate preprocessed reads sample tsv: /net/nfs-ip34/home/def-ilafores/analysis/20230216_metagenome_test/testset-projet_PROVID19-saliva/preprocess/preprocessed_reads.sample.tsv
To submit to slurm, execute the following command:
sbatch --array=1-5 /net/nfs-ip34/home/def-ilafores/analysis/20230216_metagenome_test/testset-projet_PROVID19-saliva/preprocess/preprocess.kneaddata.slurm.sh

```

**Notice** that preprocess script generates sample tsv file (i.e. precocess/preprocessed_reads.sample.tsv) that should be used
for the taxonomic profile and the functionnal profile pipeline.

Finally, the preprocess script can be executed on a single sample.
Use -h option to view usage:

```

$ bash $ILL_PIPELINES/scripts/preprocess.kneaddata.sh -h

Usage: preprocess.kneaddata.sh -s sample_name -o /path/to/out [--db] [--trimmomatic_options "trim options"] [--bowtie2_options "bowtie2 options"]
Options:

	-s STR	sample name
	-o STR	path to output dir
	-tmp STR	path to temp dir (default output_dir/temp)
	-t	# of threads (default 8)
	-m	memory (default 40G)
	-fq1	path to fastq1
	-fq2	path to fastq2
	--db	kneaddata database path (default /net/nfs-ip34/fast/def-ilafores/host_genomes/GRCh38_index/grch38_1kgmaj)
	--trimmomatic_options	options to pass to trimmomatic (default ILLUMINACLIP:/cvmfs/soft.mugqic/CentOS6/software/trimmomatic/Trimmomatic-0.39/adapters/TruSeq3-PE-2.fa:2:30:10 SLIDINGWINDOW:4:30 MINLEN:100)
	--bowtie2_options	options to pass to trimmomatic (default --very-sensitive-local)

  -h --help	Display help


```


### Run Kraken2 taxonomic profile per sample ###

For full list of options:

```
$ bash $ILL_PIPELINES/generateslurm_taxonomic_profile.sample.sh -h

Usage: generateslurm_taxonomic_profile.sample.sh --sample_tsv /path/to/tsv --out /path/to/out [--kraken_db "kraken database"]
Options:

	--sample_tsv STR	path to sample tsv (3 columns: sample name<tab>fastq1 path<tab>fastq2 path)
	--out STR	path to output dir
	--kraken_db	kraken2 database path (default /cvmfs/datahub.genap.ca/vhost34/def-ilafores/kraken2_dbs/k2_pluspfp_16gb_20210517)
	--bracken_readlen	bracken read length option (default 150)

Slurm options:
	--slurm_alloc STR	slurm allocation (default def-ilafores)
	--slurm_log STR	slurm log file output directory (default to output_dir/logs)
	--slurm_email "your@email.com"	Slurm email setting
	--slurm_walltime STR	slurm requested walltime (default 6:00:00)
	--slurm_threads INT	slurm requested number of threads (default 24)
	--slurm_mem STR	slurm requested memory (default 125)

  -h --help	Display help

```

**Notice** that preprocess script generates sample tsv file needed here (i.e. precocess/preprocessed_reads.sample.tsv).

The taxonomic profile script can also be executed on a single sample.
Use -h option to view usage:

```

$ bash $ILL_PIPELINES/scripts/taxonomic_profile.sample.sh -h

Usage: taxonomic_profile.sample.sh [--kraken_db /path/to/krakendb] [--bracken_readlen int] [--confidence float] [-t thread_nbr] [-m mem_in_G] -fq1 /path/fastq1 -fq2 /path/fastq2 -o /path/to/out
Options:

	-s STR	sample name
	-o STR	path to output dir
	-tmp STR	path to temp dir (default output_dir/temp)
	-t	# of threads (default 8)
	-m	memory (default 40G)
	-fq1	path to fastq1
	-fq2	path to fastq2
	--kraken_db	kraken2 database path (default /cvmfs/datahub.genap.ca/vhost34/def-ilafores/kraken2_dbs/k2_pluspfp_16gb_20210517)
	--bracken_readlen	bracken read length option (default 150)
    --confidence	kraken confidence level to reduce false-positive rate (default 0.05)
    
  -h --help	Display help

```

### Generate taxonomy profile on all samples for all taxonomic level ###

For full list of options:

```
$ bash $ILL_PIPELINES/generateslurm_taxonomic_profile.allsamples.sh -h

Usage: generateslurm_taxonomic_profile.allsamples.sh --kreports 'kraken_report_regex' --out /path/to/out --bowtie_index_name idx_nbame
Options:

        --kreports STR  base path regex to retrieve species level kraken reports (i.e.: /home/def-ilafores/programs/ILL_pipelines/taxonomic_profile/*/*_bracken/*_bracken_S.kreport).
        --out STR       path to output dir
        --bowtie_index_name  name of the bowtie index that will be generated
        --chocophlan_db path to the full chocoplan db (default: /net/nfs-ip34/fast/def-ilafores/humann_dbs/chocophlan)

Slurm options:
        --slurm_alloc STR       slurm allocation (default def-ilafores)
        --slurm_log STR slurm log file output directory (default to output_dir/logs)
        --slurm_email "your@email.com"  Slurm email setting
        --slurm_walltime STR    slurm requested walltime (default 24:00:00)
        --slurm_threads INT     slurm requested number of threads (default 48)
        --slurm_mem STR slurm requested memory (default 251G)

  -h --help     Display help


```

The kreports parameter is a regular expression that points to all kraken report generated at specie level.
The analysis begins and creates the buglist and then creates the bowtie index on the buglist. It finishes by 
generating the taxonomic table for each taxonomic level.

### Generate HUMAnN bugs list ###


For full list of options:

```
$ bash $ILL_PIPELINES/generateslurm_taxonomic_profile.allsamples.sh -h

Usage: generateslurm_taxonomic_profile.allsamples.sh --kreports 'kraken_report_regex' --out /path/to/out --bowtie_index_name idx_nbame
Options:

	--kreports STR	base path regex to retrieve species level kraken reports (i.e.: /home/jflucier/tmp/taxonomic_profile/*/*_bracken/*_bracken_S.kreport).
	--out STR	path to output dir
	--bowtie_index_name  name of the bowtie index that will be generated
	--chocophlan_db	path to the full chocoplan db (default: /net/nfs-ip34/fast/def-ilafores/humann_dbs/chocophlan)

Slurm options:
	--slurm_alloc STR	slurm allocation (default def-ilafores)
	--slurm_log STR	slurm log file output directory (default to output_dir/logs)
	--slurm_email "your@email.com"	Slurm email setting
	--slurm_walltime STR	slurm requested walltime (default 24:00:00)
	--slurm_threads INT	slurm requested number of threads (default 48)
	--slurm_mem STR	slurm requested memory (default 251G)

  -h --help	Display help

```

The kreports parameter is a regular expression that points to all species level kraken report files that will be used in analysis.

If you wish, the humann bug list generation can be directly runned locally on serve using similar code as below:

```
kreports="/net/nfs-ip34/home/def-ilafores//projet_PROVID19/taxKB_conf01_jfl/*/*_bracken/*_S.kreport"
out=test
tmp=test/temp
threads=24
bowtie_idx_name=my_bt_idx
choco_db=/net/nfs-ip34/fast/def-ilafores/humann_dbs/chocophlan

bash $ILL_PIPELINES//scripts/taxonomic_profile.allsamples.sh \
--kreports "$kreports" \
--out ${out} \
--tmp $tmp \
--threads ${threads} \
--bowtie_index_name $bowtie_idx_name \
--chocophlan_db $choco_db

```

### Run HUMAnN functionnal profile ###

Before running this pipeline, make sure [HUMAnN](https://huttenhower.sph.harvard.edu/humann/) environment is acessible.

For full list of options:

```
$ bash $ILL_PIPELINES/generateslurm_functionnal_profile.humann.sh -h

Usage: generateslurm_functionnal_profile.humann.sh --sample_tsv /path/to/tsv --out /path/to/out --nt_db "nt database path" [--search_mode "search mode"] [--prot_db "protein database path"]
Options:

	--sample_tsv STR	path to sample tsv (3 columns: sample name<tab>fastq1 path<tab>fastq2 path)
	--out STR	path to output dir
	--search_mode	Search mode. Possible values are: dual, nt, prot (default dual)
	--nt_db	the nucleotide database to use
	--prot_db	the protein database to use (default /home/def-ilafores/programs/ILL_pipelineshumann3/lib/python3.7/site-packages/humann/data/uniref)

Slurm options:
	--slurm_alloc STR	slurm allocation (default def-ilafores)
	--slurm_log STR	slurm log file output directory (default to output_dir/logs)
	--slurm_email "your@email.com"	Slurm email setting
	--slurm_walltime STR	slurm requested walltime (default 24:00:00)
	--slurm_threads INT	slurm requested number of threads (default 24)
	--slurm_mem STR	slurm requested memory (default 125G)

  -h --help	Display help


```

The sample_tsv that can be used was created in the preprocess step (i.e. precocess/preprocessed_reads.sample.tsv).

The functionnal profile script can also be executed on a single sample.
Use -h option to view usage:

```

$ $ILL_PIPELINES/scripts/functionnal_profile.humann.sh -h

Usage: functionnal_profile.humann.sh -s /path/to/tsv --o /path/to/out --nt_db "nt database path" [--search_mode "search mode"] [--prot_db "protein database path"]
Options:

	-s STR	sample name
	-o STR	path to output dir
	-tmp STR	path to temp dir (default output_dir/temp)
	-t	# of threads (default 8)
	-m	memory (default 30G)
	-fq	path to fastq
	--search_mode	Search mode. Possible values are: dual, nt, prot (default dual)
	--nt_db	the nucleotide database to use
	--prot_db	the protein database to use (default /home/def-ilafores/programs/ILL_pipelineshumann3/lib/python3.7/site-packages/humann/data/uniref)
	--log	logging file path (default /path/output/log.txt)

  -h --help	Display help


```

### Run MetaWRAP assembly, binning and bin refinement ###

Before running this pipeline, make sure singularity and BBmap executables are in your path. On ip29, just do the following:

```
module load singularity mugqic/BBMap/38.90

```

For full list of options:

```

$ bash ${ILL_PIPELINES}/generateslurm_assembly_bin_refinement.metawrap.sh -h

Usage: generateslurm_denovo_assembly_bin_refinement.metawrap.sh --sample_tsv /path/to/tsv --out /path/to/out [--assembly] [--binning] [--refinement]
Options:

    --sample_tsv STR	path to sample tsv (3 columns: sample name<tab>fastq1 path<tab>fastq2 path)
	--out STR	path to output dir
	--assembly	perform assembly
	--binning	perform binning step
	--refinement	perform refinement step

Metawrap options:
	--metaspades	use metaspades for assembly (default: true)
	--megahit	use megahit for assembly (default: true)
	--metabat2	use metabat2 for binning (default: true)
	--maxbin2	use maxbin2 for binning (default: true)
	--concoct	use concoct for binning (default: true)
	--run-checkm	run checkm for binning (default: true)
	--refinement_min_compl INT	refinement bin minimum completion percent (default 50)
	--refinement_max_cont INT	refinement bin maximum contamination percent (default 10)

Slurm options:
	--slurm_alloc STR	slurm allocation (default def-ilafores)
	--slurm_log STR	slurm log file output directory (default to output_dir/logs)
	--slurm_email "your@email.com"	Slurm email setting
	--slurm_walltime STR	slurm requested walltime (default 24:00:00)
	--slurm_threads INT	slurm requested number of threads (default 48)
	--slurm_mem STR	slurm requested memory (default 251G)

  -h --help	Display help


```

Most default values should be ok in a cluster environment. Make sure you specify sample_tsv, ouput path and steps you wich to execute (assembly and/or binning and/or refinement). Obviously, before running binning, you must perform assembly step.

The sample_tsv that can be used was created in the preprocess step (i.e. precocess/preprocessed_reads.sample.tsv).

Here a re some example commands you can perform for this pipeline:
```
# on ip29, load singularity and bbmap in path
module load singularity mugqic/BBMap/38.90

# Run all steps with defualt parameters
$ bash ${ILL_PIPELINES}/generateslurm_assembly_bin_refinement.metawrap.sh \
--out path/to/out --sample_tsv /path/to/tsv

# Run only the assembly step
$ bash ${ILL_PIPELINES}/generateslurm_assembly_bin_refinement.metawrap.sh \
--out path/to/out --sample_tsv /path/to/tsv \
--assembly

# Run only the assembly step using only megahit assembler
$ bash ${ILL_PIPELINES}/generateslurm_assembly_bin_refinement.metawrap.sh \
--out path/to/out --sample_tsv /path/to/tsv \
--assembly --megahit

# Run the assembly step using only megahit assembler and binning step with
# concoct and maxbin binner software
$ bash ${ILL_PIPELINES}/generateslurm_assembly_bin_refinement.metawrap.sh \
--out path/to/out --sample_tsv /path/to/tsv \
--assembly --megahit \
--binning --maxbin2 --concoct

# Run assembly and binning with default paramters and refinement step using
# specific bin completion and contamination values
$ bash ${ILL_PIPELINES}/generateslurm_assembly_bin_refinement.metawrap.sh \
--out path/to/out --sample_tsv /path/to/tsv \
--assembly --binning \
--refinement --refinement_min_compl 90 --refinement_max_cont 5

```

Finally, the assembly, binning and refinement script can be executed on a single sample.
Use -h option to view usage:

```
# on ip29, load singularity and bbmap in path
module load singularity mugqic/BBMap/38.90


## assembly script usage:
$ bash /home/jflucier/localhost/projet/ILL_pipelines/scripts/assembly.metawrap.sh -h

Usage: assembly.metawrap.sh [-tmp /path/tmp] [-t threads] [-m memory] [--metaspades] [--megahit] -s sample_name -o /path/to/out -fq1 /path/to/fastq1 -fq2 /path/to/fastq2
Options:

	-s STR	sample name
	-o STR	path to output dir
	-tmp STR	path to temp dir (default output_dir/temp)
	-t	# of threads (default 8)
	-m	memory (default 40G)
	-fq1	path to fastq1
	-fq2	path to fastq2
	--metaspades	use metaspades for assembly (default: true)
	--megahit	use megahit for assembly (default: true)

  -h --help	Display help

## Binning script usage:
$ bash $ILL_PIPELINES/scripts/binning.metawrap.sh -h

Usage: binning.metawrap.sh [-tmp /path/tmp] [-t threads] [-m memory] [--metabat2] [--maxbin2] [--concoct] [--run-checkm] -s sample_name -o /path/to/out -a /path/to/assembly -fq1 /path/to/fastq1 -fq2 /path/to/fastq2
Options:

	-s STR	sample name
	-o STR	path to output dir
	-tmp STR	path to temp dir (default output_dir/temp)
	-t	# of threads (default 8)
	-m	memory (default 40G)
	-a	assembly fasta filepath
	-fq1	path to fastq1
	-fq2	path to fastq2
	--metabat2	use metabat2 for binning (default: true)
	--maxbin2	use maxbin2 for binning (default: true)
	--concoct	use concoct for binning (default: true)
	--run-checkm	run checkm on bins (default: true)

  -h --help	Display help


## Binning refinement script usage:
$ $ILL_PIPELINES/scripts/bin_refinement.metawrap.sh -h

Usage: bin_refinement.metawrap.sh [-tmp /path/tmp] [-t threads] [-m memory] [--metaspades] [--megahit] -s sample_name -o /path/to/out -fq1 /path/to/fastq1 -fq2 /path/to/fastq2
Options:

	-s STR	sample name
	-o STR	path to output dir
	-tmp STR	path to temp dir (default output_dir/temp)
	-t	# of threads (default 8)
	-m	memory (default 40G)
	--metabat2_bins	path to metabats bin direcotry
	--maxbin2_bins	path to maxbin2 bin direcotry
	--concoct_bins	path to concoct bin direcotry
	--refinement_min_compl INT	refinement bin minimum completion percent (default 50)
	--refinement_max_cont INT	refinement bin maximum contamination percent (default 10)

  -h --help	Display help

```

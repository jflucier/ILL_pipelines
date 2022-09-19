# ILL Humann custom pipeline User Manual

Slightly modified humann pipeline to optimise performance.

----

## Contents ##

* [Requirements](#requirements)
* [Installation](#initial-installation)
* [How to run](#how-to-run)
    * [Run preprocess kneaddata](#Run-preprocess-kneaddata)
    * [Run taxonomic profile on samples](#Run-taxonomic-profile-on-samples)
    * [Run HUMAnN functionnal profile on samples](#Run-HUMAnN-functionnal-profile-on-samples)
    * [Run assembly, binning and bin refinement](#Run-assembly,-binning-and-bin-refinement)

----

## Requirements ##

1. [BBMap](https://jgi.doe.gov/data-and-tools/software-tools/bbtools/bb-tools-user-guide/bbmap-guide/)
2. [Singularity](https://docs.sylabs.io/guides/3.0/user-guide/index.html)
3. [kneaddata](https://github.com/biobakery/kneaddata)
4. [Kraken2](https://github.com/DerrickWood/kraken2)
5. [Bracken](https://github.com/jenniferlu717/Bracken)
6. [KronaTools](https://github.com/marbl/Krona/tree/master/KronaTools)
7. [HUMAnN](https://huttenhower.sph.harvard.edu/humann/)


Please install the required software in a location of your choice and put in PATH variable.

----

## Initial Installation ##

To install ILL pipelines you need to:

* Create a clone of the repository:

    ``git clone https://github.com/jflucier/ILL_pipelines.git ``

    Note: Creating a clone of the repository requires [Github](https://github.com/) to be installed.

* For convenience, set environment variable ILL_PIPELINES in your ~/.bashrc:

    ``export ILL_PIPELINES=/path/to/ILL_pipelines ``

    Note: On ip29, ILL pipelines path is /project/def-ilafores/common/ILL_pipelines


----

## How to run ##

To run pipelines you need to create a sample spread with 3 columns like this table:

| sample1 	| /path/to/sample1.R1.fastq 	| /path/to/sample1.R2.fastq 	|
| sample2 	| /path/to/sample2.R1.fastq 	| /path/to/sample2.R2.fastq 	|
| etc...  	| etc...                    	| etc...                    	|

**Important note: TSV files must not have header line.**

### Run preprocess kneaddata pipelines ###

Before running this pipeline, make sure [kneaddata](https://github.com/biobakery/kneaddata) is installed.

For full list of options:

```
$ bash $ILL_PIPELINES/generateslurm_preprocess.kneaddata.sh -h

Usage: generateslurm_preprocess.kneaddata.sh --sample_tsv /path/to/tsv --out /path/to/out [--db] [--trimmomatic_options "trim options"] [--bowtie2_options "bowtie2 options"]
Options:

	--sample_tsv STR	path to sample tsv (3 columns: sample name<tab>fastq1 path<tab>fastq2 path)
	--out STR	path to output dir
	--db	kneaddata database path (default /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/host_genomes/GRCh38_index/grch38_1kgmaj)
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

Most default values should be ok on ip29. Make sure you specify sample_tsv, ouput path.

Here is how generate slurm script with default paramters:
```

$ bash $ILL_PIPELINES/generateslurm_preprocess.kneaddata.sh --out precocess/ --sample_tsv samples.tsv
## Will use sample file: samples.tsv
## Results wil be stored to this path: precocess/
## Slurm output path not specified, will output logs in: precocess//logs
outputting preprocess slurm script to precocess//preprocess.kneaddata.slurm.sh
Generate taxonomic profiling sample tsv: precocess//taxonomic_profile.sample.tsv
Generate functionnal profiling sample tsv: precocess//functionnal_profile.sample.tsv
To submit to slurm, execute the following command:
sbatch --array=1-187 precocess//preprocess.kneaddata.slurm.sh

```

Notice that preprocess script generates 2 tab seperated sample files that should be used
for the taxonomic profile pipeline and for the functionnal profile pipeline.

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
	--db	kneaddata database path (default /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/host_genomes/GRCh38_index/grch38_1kgmaj)
	--trimmomatic_options	options to pass to trimmomatic (default ILLUMINACLIP:/cvmfs/soft.mugqic/CentOS6/software/trimmomatic/Trimmomatic-0.39/adapters/TruSeq3-PE-2.fa:2:30:10 SLIDINGWINDOW:4:30 MINLEN:100)
	--bowtie2_options	options to pass to trimmomatic (default --very-sensitive-local)

  -h --help	Display help


```


### Run taxonomic profile on samples ###

Before running this pipeline, make sure [kraken2](https://github.com/DerrickWood/kraken2), [Bracken](https://github.com/jenniferlu717/Bracken) and [KronaTools](https://github.com/marbl/Krona/tree/master/KronaTools) and acessible in PATH variable.

For full list of options:

```
$ bash $ILL_PIPELINES/generateslurm_taxonomic_profile.sample.sh -h

Usage: generateslurm_taxonomic_profile.sample.sh --sample_tsv /path/to/tsv --out /path/to/out [--db] [--trimmomatic_options "trim options"] [--bowtie2_options "bowtie2 options"]
Options:

	--sample_tsv STR	path to sample tsv (3 columns: sample name<tab>fastq1 path<tab>fastq2 path)
	--out STR	path to output dir
	--kraken_db	kraken2 database path (default /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/kraken2_dbs/k2_pluspfp_16gb_20210517)
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

The taxonomic profile script can also be executed on a single sample.
Use -h option to view usage:

```

$ $ILL_PIPELINES/scripts/taxonomic_profile.sample.sh -h

Usage: taxonomic_profile.sample.sh -s sample_name -o /path/to/out [--db] [--trimmomatic_options "trim options"] [--bowtie2_options "bowtie2 options"]
Options:

	-s STR	sample name
	-o STR	path to output dir
	-tmp STR	path to temp dir (default output_dir/temp)
	-t	# of threads (default 8)
	-m	memory (default 40G)
	-fq1	path to fastq1
	-fq2	path to fastq2
	--kraken_db	kraken2 database path (default /nfs3_ib/ip29-ib/ssdpool/shared/ilafores_group/kraken2_dbs/k2_pluspfp_16gb_20210517)
	--bracken_readlen	bracken read length option (default 150)

  -h --help	Display help

```

### Run HUMAnN functionnal profile on samples ###

Before running this pipeline, make sure [HUMAnN](https://huttenhower.sph.harvard.edu/humann/) conda environment is acessible via the conda activate command.

For full list of options:

```
$ bash $ILL_PIPELINES/generateslurm_functionnal_profile.humann.sh -h

Usage: generateslurm_functionnal_profile.humann.sh --sample_tsv /path/to/tsv --out /path/to/out --nt_db "nt database path" [--search_mode "search mode"] [--prot_db "protein database path"]
Options:

	--sample_tsv STR	path to sample tsv (3 columns: sample name<tab>fastq1 path<tab>fastq2 path)
	--out STR	path to output dir
	--search_mode	Search mode. Possible values are: dual, nt, prot (default dual)
	--nt_db	the nucleotide database to use
	--prot_db	the protein database to use (default /project/def-ilafores/common/humann3/lib/python3.7/site-packages/humann/data/uniref)

Slurm options:
	--slurm_alloc STR	slurm allocation (default def-ilafores)
	--slurm_log STR	slurm log file output directory (default to output_dir/logs)
	--slurm_email "your@email.com"	Slurm email setting
	--slurm_walltime STR	slurm requested walltime (default 24:00:00)
	--slurm_threads INT	slurm requested number of threads (default 24)
	--slurm_mem STR	slurm requested memory (default 125G)

  -h --help	Display help


```

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
	--prot_db	the protein database to use (default /project/def-ilafores/common/humann3/lib/python3.7/site-packages/humann/data/uniref)
	--log	logging file path (default /path/output/log.txt)

  -h --help	Display help


```

### Run assembly, binning and bin refinement pipelines ###

Before running this pipeline, make sure singularity and BBmap executables are in your path.

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

Here a re some example commands you can perform for this pipeline:
```

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

Finally, the assembly, binng and refinement script can be executed on a single sample.
Use -h option to view usage:

```

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

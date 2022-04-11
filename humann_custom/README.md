# ILL Humann custom pipeline User Manual

Slightly modified humann pipeline to optimse performance.

----

## Contents ##

* [Requirements](#requirements)
* [Installation](#initial-installation)
* [How to run](#how-to-run)
    * [Make custom buglist input](#make-custom-buglist-input)
    * [Make custom buglist database](#make-custom-buglist-database)
    * [Run custom human pipeline](#run-pipeline)
* [Output files](#output-files)

----

## Requirements ##

1. [humann](https://huttenhower.sph.harvard.edu/humann/) (version >= 3.0)
2. [bowtie2](http://bowtie-bio.sourceforge.net/bowtie2/index.shtml) (version >= 2.3.5)
3. [samtools](http://www.htslib.org/) (version >= 1.14)
4. [diamond](https://github.com/bbuchfink/diamond) (version >= 2.0.14)

Please install the required software in a location of your choice and put in PATH variable.

```
export PATH=/path/to/bowtie2:$PATH"
export PATH=/path/to/samtools:$PATH
export PATH=/path/to/diamond:$PATH
```

Before using humann_custom pipeline, make sure you create a configuration file (see install section).

----

## Initial Installation ##

To install humann_custom you need to:

* Create a clone of the repository:

    ``$ git clone https://github.com/jflucier/ILL_pipelines.git ``

    Note: Creating a clone of the repository requires [Github](https://github.com/) to be installed.


----

## How to run ##

To run pipelines in this repository you first need to COPY and EDIT example configuration
file /path/to/ILL_pipelines/humann_custom/my.example.config

```
cp /path/to/ILL_pipelines/humann_custom/my.example.config .
cp /path/to/ILL_pipelines/humann_custom/buglist.sample.test.tsv .
cp /path/to/ILL_pipelines/humann_custom/humann.sample.tsv .
vi my_analysis.config
```

As mentionned in example configuration file, you need to defined the HUMANN_RUN_SAMPLE_TSV and CUSTOM_DB_SAMPLE_TSV variables.

CUSTOM_DB_SAMPLE_TSV is a tab seperated files with 3 columns similar to this table:

| sample1 	| /path/to/sample1.R1.fastq 	| /path/to/sample1.R2.fastq 	|
| sample2 	| /path/to/sample2.R1.fastq 	| /path/to/sample2.R2.fastq 	|
| etc...  	| etc...                    	| etc...                    	|

**TSV files must not have header line.**

HUMANN_RUN_SAMPLE_TSV is a tab seperated files with 2 columns similar to this table:

| sample1 	| /path/to/sample1.fastq 	|
| sample2 	| /path/to/sample2.fastq 	|
| etc...  	| etc...                 	|

**TSV files must not have header line.** This listing can be performed after the 01_make_custom_buglist_input.sh
and 02_make_humann_buglist_db.sh steps sucessfully complete.


### Make custom buglist input ###

```

$ bash /path/to/ILL_pipelines/humann_custom/01_make_custom_buglist_input.sh my.example.config

```

### Make custom buglist database ###

```

$ bash /path/to/ILL_pipelines/humann_custom/02_make_humann_buglist_db.sh my.example.config

```

### Run custom human pipeline ###

```

$ bash /path/to/ILL_pipelines/humann_custom/03_humann_custom_run.sh my.example.config

```


----

## Output files ##

SEction need documentation!!!

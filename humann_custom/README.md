# E2EAssembler 1.0 User Manual

End to end chromosome assembly for long read sequencing data.

----

## Contents ##

* [Requirements](#requirements)
* [Installation](#initial-installation)
* [How to run](#how-to-run)
* [Output files](#output-files)

----

## Requirements ##

1. [bowtie2](http://bowtie-bio.sourceforge.net/bowtie2/index.shtml) (tested with version >= 2.3.5)
2. [samtools](http://www.htslib.org/) (version >= 1.14)
3. [diamond](https://github.com/bbuchfink/diamond) (version >= 2.0.14)

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

* Copy example humann_custom configuration file /path/to/ILL_pipelines/humann_custom/my.example.config and edit with your required analysis parameters.

```
cp /path/to/ILL_pipelines/humann_custom/my.example.config my_analysis.config"
vi my_analysis.config
```

----

## How to run ##


```

$ bash /path/to/ILL_pipelines/humann_custom/run_custom_humann.sh my_analysis.config

```


----

## Output files ##

SEction need documentation!!!

# nf-biohansel-sra-benchmark

[![Build Status](https://dev.azure.com/peterkruczkiewicz0831/nf-biohansel-sra-benchmark/_apis/build/status/peterk87.nf-biohansel-sra-benchmark?branchName=master)](https://dev.azure.com/peterkruczkiewicz0831/nf-biohansel-sra-benchmark/_build/latest?definitionId=2&branchName=master)
[![https://www.singularity-hub.org/static/img/hosted-singularity--hub-%23e32929.svg](https://www.singularity-hub.org/static/img/hosted-singularity--hub-%23e32929.svg)](https://singularity-hub.org/collections/3444)


Nextflow workflow for benchmarking [biohansel](https://github.com/phac-nml/biohansel) and [Snippy](https://github.com/tseemann/snippy/) with NCBI SRA genomes.


## Pre-reqs

- Install [Nextflow](https://www.nextflow.io/)
- Install [Conda](https://docs.conda.io/en/latest/miniconda.html)
- One or more directories each with the following files (see `schemes/enteritidis_v1.0.7` for an example)
 - `accessions` - List of SRA run accessions (e.g. `SRR8820085`) in a file (one accession per line)
 - `scheme.fasta` - biohansel scheme definition file
 - `ref.gb` - Genbank format reference genome
 - `metadata.tsv` tab delimited metadata file or empty file
 
Input scheme directory included with this repo:

```
schemes
└── enteritidis_v1.0.7
    ├── accessions
    ├── metatadata.tsv
    ├── ref.gb
    └── scheme.fasta
```

## Usage

Show help message:

```
nextflow run peterk87/nf-biohansel-sra-benchmark --help
```

Should see something like:

```
N E X T F L O W  ~  version 19.07.0-edge
Launching `main.nf` [drunk_dalembert] - revision: 97a449f5b6
==================================================================
peterk87/nf-biohansel-sra-benchmark  ~  version 1.0dev
==================================================================

Git info: null - null [null]

Usage:
 The typical command for running the pipeline is as follows:

 nextflow run peterk87/nf-biohansel-sra-benchmark \
   --outdir results \
   --schemesdir schemes \
   --n_genomes 96 \
   --iterations 10 \
   -work workdir \
   -profile standard

Options:
  --outdir         Output directory (default: results)
  --schemesdir     Directory with subtyping schemes and accessions to benchmark with biohansel (default: schemes)
  --n_genomes      Number of SRA genomes to download and analyze per scheme (default: 96)
  --iterations     Number of iterations per biohansel benchmark (default: 10)
  --thread_combos  List of integer number of threads to test biohansel and snippy with delimited by comma (default: 1,2,4,8,16,32)
Other options:
  -w/--work-dir    The temporary directory where intermediate data will be saved (default: work)
  -profile         Configuration profile to use. [singularity, conda, slurm] (default: standard)
Cluster options:
  -profile         Only "-profile slurm" is accepted
  --slurm_queue    Name of SLURM queue to submit jobs to (e.g. "HighPriority").
```


Run test profile creating Conda environment:

```
nextflow run peterk87/nf-biohansel-sra-benchmark -profile test,conda
```

Run included benchmark dataset with Singularity and default parameters (i.e. 96 genomes, 10 iterations for biohansel, run Snippy and biohansel with 1,2,4,8,16,32 threads/CPUs):

```
# clone/download this repo so that the scheme included with this repo can be run with the workflow
git clone https://github.com/peterk87/nf-biohansel-sra-benchmark.git
nextflow run peterk87/nf-biohansel-sra-benchmark -profile singularity --schemesdir nf-biohansel-sra-benchmark/schemes
```

Run above on a cluster with SLURM:

```
git clone https://github.com/peterk87/nf-biohansel-sra-benchmark.git
nextflow run peterk87/nf-biohansel-sra-benchmark -profile singularity,slurm --slurm_queue <QueueName> --schemesdir nf-biohansel-sra-benchmark/schemes
```

## Pipeline run information

Within your output directory (e.g. `results/`), you should find a `pipeline_info` directory with runtime information about your analysis including trace information (see https://www.nextflow.io/docs/latest/tracing.html for more info about these output files)


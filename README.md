# nf-biohansel-sra-benchmark

Basic Nextflow workflow for benchmarking [biohansel](https://github.com/phac-nml/biohansel) against NCBI SRA samples

## Pre-reqs

- Install [Nextflow](https://www.nextflow.io/)
- Install [Conda](https://docs.conda.io/en/latest/miniconda.html)
- List of SRA run accessions (e.g. `SRR8820085`) in a file (one accession per line)

## Usage

Show help message:

```
nextflow run peterk87/nf-biohansel-sra-benchmark --help
```

Should see something like:

```
N E X T F L O W  ~  version 19.01.0
Launching `peterk87/nf-biohansel-sra-benchmark` [insane_faggin] - revision: 3c2150da5c [master]

==================================================================
null  ~  version null
==================================================================

Git info: https://github.com/peterk87/nf-biohansel-sra-benchmark.git - master [3c2150da5c675359f81c452376722c11d89ecc53]

Usage:
 The typical command for running the pipeline is as follows:
 nextflow run main.nf -profile standard --outdir /output/path 
Options:
  --accessions                 List of SRA accessions; one per line (default: "./accessions.txt")
  --outdir                     Output directory (default: "./results")
  --scheme                     biohansel subtyping scheme (default: heidelberg)
Other options:
  -w/--work-dir                The temporary directory where intermediate data will be saved
  -profile                     Configuration profile to use. [standard, other_profiles] (default 'standard')
```


Run test SRAs from [`accessions.txt`](https://github.com/peterk87/nf-biohansel-sra-benchmark/tree/master/accessions.txt):

```
nextflow run peterk87/nf-biohansel-sra-benchmark
```

Run your own list of SRAs with the `heidelberg` scheme:

```
nextflow run peterk87/nf-biohansel-sra-benchmark --accessions accessions.txt --scheme heidelberg
```

## Pipeline run information

Within your output directory, you should find a `pipeline_info` directory with runtime information about your analysis including trace information (see https://www.nextflow.io/docs/latest/tracing.html for more info about these output files)


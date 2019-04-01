# nf-biohansel-sra-benchmark

Basic Nextflow workflow for benchmarking biohansel against NCBI SRA samples

## Pre-reqs

- Install [Nextflow](https://www.nextflow.io/)
- Install [Conda](https://docs.conda.io/en/latest/miniconda.html)
- List of SRA run accessions (e.g. `SRR8820085`) in a file (one accession per line)

## Usage

```
nextflow run peterk87/nf-biohansel-sra-benchmark --accessions accessions.txt --scheme heidelberg
```


#!/usr/bin/env nextflow

params.accessions = "$baseDir/accessions.txt"
params.outdir = "results"
params.help = false
params.scheme = 'heidelberg'
params.biohansel_threads = 2

outdir = params.outdir

def helpMessage() {
  log.info"""
  ==================================================================
  ${workflow.manifest.name}  ~  version ${workflow.manifest.version}
  ==================================================================

  Git info: $workflow.repository - $workflow.revision [$workflow.commitId]

  Usage:
   The typical command for running the pipeline is as follows:
   nextflow run main.nf -profile standard --outdir /output/path 
  Options:
    --accessions                 List of SRA accessions; one per line (default: "$baseDir/accessions.txt")
    --outdir                     Output directory (default: "$baseDir/results")
    --scheme                     biohansel subtyping scheme (default: $params.scheme)
  Other options:
    -w/--work-dir                The temporary directory where intermediate data will be saved
    -profile                     Configuration profile to use. [standard, other_profiles] (default 'standard')
  """.stripIndent()
}

// Show help message if --help specified
if (params.help){
  helpMessage()
  exit 0
}

if (workflow.profile == 'slurm' && params.slurm_queue == "") {
  log.error "You must specify a valid SLURM queue (e.g. '--slurm_queue <queue name>' (see `\$ sinfo` output for available queues)) to run this workflow with the 'slurm' profile!"
  exit 1
}

log.info """
==============================
Pipeline Initialization Info
==============================
Project : $workflow.projectDir
Git info: $workflow.repository - $workflow.revision [$workflow.commitId]
Cmd line: $workflow.commandLine
Params  : $params
Nextflow version: $workflow.nextflow.version
------------------------------
"""

Channel
  .fromPath(params.accessions)
  .splitText()
  .map { it.replaceAll("\\s", "") }
  .filter { it != '' }
  .dump(tag: "ch_accessions")
  .set { ch_accessions }

process fasterq_dump {
  tag "$accession"
  publishDir "$outdir/fastqs/$accession", mode: 'symlink', pattern: "*.fastq"
  conda 'bioconda::sra-tools'
  cpus 2

  input:
    val(accession) from ch_accessions
  output:
    set val(accession), file("*.fastq") into ch_fastqs

  """
  fasterq-dump $accession -e ${task.cpus}
  """
}

ch_fastqs
  .flatMap { it[1] }
  .collect()
  .dump(tag: "ch_collected_fastqs")
  .set { ch_collected_fastqs }

process biohansel {
//  tag "$accession"
  conda 'bioconda::bio_hansel=2.2.0 conda-forge::pyahocorasick'
  publishDir "$outdir/biohansel", mode: 'copy', pattern: "*.tsv"
  cpus params.biohansel_threads

  input:
    file(reads) from ch_collected_fastqs
  output:
    set file(detailed_report), file(summary_report) into ch_biohansel
  script:
  detailed_report = "biohansel-detailed_report.tsv"
  summary_report = "biohansel-summary_report.tsv"
  """
  hansel -v -t ${task.cpus} -s ${params.scheme} -D ./ -o $summary_report -O $detailed_report
  """
}

workflow.onComplete {
    println """
    Pipeline execution summary
    ---------------------------
    Completed at : ${workflow.complete}
    Duration     : ${workflow.duration}
    Success      : ${workflow.success}
    Results Dir  : ${file(params.outdir)}
    Work Dir     : ${workflow.workDir}
    Exit status  : ${workflow.exitStatus}
    Error report : ${workflow.errorReport ?: '-'}
    """.stripIndent()
}
workflow.onError {
    println "Oops... Pipeline execution stopped with the following message: ${workflow.errorMessage}"
}


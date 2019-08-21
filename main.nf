#!/usr/bin/env nextflow

def helpMessage() {
  log.info"""
  ==================================================================
  ${workflow.manifest.name}  ~  version ${workflow.manifest.version}
  ==================================================================

  Git info: $workflow.repository - $workflow.revision [$workflow.commitId]

  Usage:
   The typical command for running the pipeline is as follows:
   
   nextflow run $workflow.manifest.name \\
     --outdir $params.outdir \\
     --schemesdir $params.schemesdir \\
     --n_genomes $params.n_genomes \\
     --iterations $params.iterations \\
     -work workdir \\
     -profile $workflow.profile

  Options:
    --outdir         Output directory (default: $params.outdir)
    --schemesdir     Directory with subtyping schemes and accessions to benchmark with biohansel (default: $params.schemesdir)
    --n_genomes      Number of SRA genomes to download and analyze per scheme (default: $params.n_genomes)
    --iterations     Number of iterations per biohansel benchmark (default: $params.iterations)
    --thread_combos  List of integer number of threads to test biohansel and snippy with delimited by comma (default: $params.thread_combos)
  Other options:
    -w/--work-dir    The temporary directory where intermediate data will be saved (default: $workflow.workDir)
    -profile         Configuration profile to use. [singularity, conda, slurm] (default: $workflow.profile)
  Cluster options:
    -profile         Only "-profile slurm" is accepted
    --slurm_queue    Name of SLURM queue to submit jobs to (e.g. "HighPriority").
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

// Has the run name been specified by the user?
//  this has the bonus effect of catching both -name and --name
custom_runName = params.name
if( !(workflow.runName ==~ /[a-z]+_[a-z]+/) ){
  custom_runName = workflow.runName
}

thread_combos = []
if (params.thread_combos instanceof String) {
  params.thread_combos.split(',').each({
    try {
      thread_combos << Integer.parseInt(it)
    } catch(Exception ex) {
      log.error "Error parsing thread_combos integers: ${ex}"
    }
  })
} else if (params.thread_combos instanceof Integer) {
  thread_combos << params.thread_combos
} else {
  log.error "Unexpected value '${params.thread_combos}' for '--thread_combos' of type ${params.thread_combos.getClass()}"
  exit 1
}


if (thread_combos.size() == 0) {
  log.error "You must specify at least one integer thread value in '--thread_combos'"
  exit 1
}

// Header log info
log.info """=======================================================
${workflow.manifest.name} v${workflow.manifest.version}
======================================================="""
def summary = [:]
summary['Pipeline Name']  = workflow.manifest.name
summary['Pipeline Version'] = workflow.manifest.version
summary['Run Name']     = custom_runName ?: workflow.runName
summary['Schemes Directory'] = params.schemesdir
summary['# SRA genomes'] = params.n_genomes
summary['Iterations'] = params.iterations
summary['Thread Combos'] = thread_combos
summary['Max Memory']   = params.max_memory
summary['Max CPUs']     = params.max_cpus
summary['Max Time']     = params.max_time
summary['Container Engine'] = workflow.containerEngine
if(workflow.containerEngine) summary['Container'] = workflow.container
summary['Current home']   = "$HOME"
summary['Current user']   = "$USER"
summary['Current path']   = "$PWD"
summary['Working dir']    = workflow.workDir
summary['Output dir']     = params.outdir
summary['Script dir']     = workflow.projectDir
summary['Config Profile'] = workflow.profile
log.info summary.collect { k,v -> "${k.padRight(15)}: $v" }.join("\n")
log.info "========================================="

outdir = params.outdir

baseSchemesDir = file(params.schemesdir)
if (!baseSchemesDir.exists()) {
  log.error "The schemes base directory does not exist at '$baseSchemesDir'!"
  exit 1
}

schemes = []

baseSchemesDir.eachDir { dir ->
  scheme = [dir.getName(), null, null, null, null]
  for (def f in dir.listFiles()) {
    switch(f.getName()) {
      case 'scheme.fasta':
        scheme[1] = f
        break
      case 'accessions':
        scheme[2] = f
        break
      case 'metadata.tsv':
        scheme[3] = f
        break
      case 'ref.gb':
        scheme[4] = f
        break
    }
  }
  schemes << scheme
}

Channel.from(schemes)
  .into { ch_schemes }

process shuffle_accessions {
  tag "seed=$params.random_seed"

  input:
    set val(scheme), file(scheme_fasta), val(accessions), file(metadata), file(ref_genbank) from ch_schemes
  output:
    set val(scheme), file(scheme_fasta), file("shuffled_accessions"), file(metadata), file(ref_genbank) into ch_schemes_shuffled

  
  """
  shuffle_lines.py --input-file $accessions --output-file shuffled_accessions --random-seed $params.random_seed
  """
}

ch_schemes_shuffled
  .splitText(limit: params.n_genomes, elem: 2)
  .map { item ->
    item[2] = item[2].replaceAll("\\s", "")
    item
  }
  .filter { it[2] != '' }
  .dump(tag: "ch_accessions")
  .set { ch_accessions }


process fasterq_dump {
  tag "$accession"
  publishDir "$outdir/fastqs/$scheme/$accession", mode: 'symlink', pattern: "*.fastq.gz"
  maxForks 4

  input:
    set val(scheme), file(scheme_fasta), val(accession), file(metadata), file(ref_genbank) from ch_accessions
  output:
    set val(scheme), file(scheme_fasta), val(accession), file(reads1), file(reads2), file(metadata), file(ref_genbank) into ch_fastqs, ch_fastqs_2, ch_fastqs_snippy, ch_fastqs_for_wc

  script:
  fq_1 = "${accession}_1.fastq"
  fq_2 = "${accession}_2.fastq"
  reads1 = "${fq_1}.gz"
  reads2 = "${fq_2}.gz"
  """
  fasterq-dump $accession -e ${task.cpus} -o $accession -S
  clumpify.sh -Xmx16g in=$fq_1 in2=$fq_2 out=$reads1 out2=$reads2 deleteinput=t
  """
}

ch_fastqs
  .groupTuple(by: 0)
  .map { it -> 
    it[1] = it[1][0]
    it[3] = it[3].flatten()
    it[4] = it[4].flatten()
    it[5] = it[5][0]
    it[6] = it[6][0]
    it
  }
  .dump(tag: "ch_collected_fastqs")
  .set { ch_collected_fastqs }

process biohansel {
  tag "$scheme|N=${nSamples}|T=$nthreads|i=$iter"
  publishDir "$outdir/biohansel/$scheme/$nthreads/$iter", mode: 'copy', pattern: "*.tsv"
  cpus { nthreads }

  input:
    each iter from 1..params.iterations
    each nthreads from thread_combos
    set val(scheme), file(scheme_fastas), val(accession), file(reads1), file(reads2), file(metadata), file(ref_genbank) from ch_collected_fastqs
  output:
    set file(detailed_report), file(summary_report) into ch_biohansel
    set val(scheme), val(nSamples), val(nthreads), val('multiple'), file('.command.trace'), val(iter), file(reads1), file(reads2) into ch_biohansel_multi_trace
  script:
  nSamples = reads1.size() 
  detailed_report = "biohansel-detailed_report.tsv"
  summary_report = "biohansel-summary_report.tsv"
  schema_fa = scheme_fastas[0]
  md = metadata.size() == 0 ? '' : " -M ${metadata}"
  """
  echo "iteration=$iter; threads=$nthreads"
  mkdir -p reads
  ln -s `realpath *.fastq.gz` reads/
  hansel \\
    -v $md \\
    -t $nthreads \\
    -s $schema_fa \\
    -D reads/ \\
    -o $summary_report \\
    -O $detailed_report
  """
}

process biohansel_single_cpu {
  tag "$scheme|$accession|$iter"
  publishDir "$outdir/biohansel/singles", mode: 'copy', pattern: "*.tsv"
  cpus 1

  input:
    each iter from 1..params.iterations
    set val(scheme), file(scheme_fasta), val(accession), file(reads1), file(reads2), file(metadata), file(ref_genbank) from ch_fastqs_2
  output:
    set file(detailed_report), file(summary_report) into ch_biohansel_singles
    set val(scheme), val(1), val(1), val('single'), file('.command.trace'), val(iter), file(reads1), file(reads2) into ch_biohansel_single_trace
  script:
  detailed_report = "biohansel-detailed_report-${accession}.tsv"
  summary_report = "biohansel-summary_report-${accession}.tsv"
  md = metadata.size() == 0 ? '' : " -M $metadata"
  """
  mkdir -p reads
  ln -s `realpath *.fastq.gz` reads/
  hansel \\
    -v $md \\
    -t ${task.cpus} \\
    -s $scheme_fasta \\
    -D reads/ \\
    -o $summary_report \\
    -O $detailed_report
  """
}


process snippy {
  tag "CPU=$ncpus|$accession"
  //publishDir "$outdir/snippy/$accession", pattern: "*.", mode: 'copy'
  cpus { ncpus }

  input:
    each ncpus from thread_combos
    set val(scheme), file(scheme_fasta), val(accession), file(reads1), file(reads2), file(metadata), file(ref_genbank) from ch_fastqs_snippy
  output:
    set val(scheme), val(1), val(ncpus), val('snippy'), file('.command.trace'), val(1), file(reads1), file(reads2) into ch_snippy_trace

  script:
  """
  snippy --prefix $accession \\
    --outdir out \\
    --cpus ${task.cpus} \\
    --R1 $reads1 \\
    --R2 $reads2 \\
    --ref $ref_genbank \\
    --cleanup \\
    --tmpdir ./
  """
}


ch_biohansel_multi_trace.mix(ch_biohansel_single_trace, ch_snippy_trace)
  .collectFile() { scheme, samples, threads, type, trace_file, iter, reads1, reads2 ->
    size_bytes = 0
    if (reads1 instanceof ArrayList) {
      reads1.collect( { size_bytes += file(it).size() } )
      reads2.collect( { size_bytes += file(it).size() } )
    } else {
      size_bytes = file(reads1).size() + file(reads2).size()
    }
    ['trace.txt', 
     """
     ${trace_file.text}
     scheme=${scheme}
     samples=${samples}
     threads=${threads}
     type=${type}
     iter=${iter}
     size_bytes=${size_bytes}
     @@@
     """.stripIndent()]
  }
  .set { ch_trace }

process trace_table {
  publishDir "$outdir/trace", pattern: "*.csv", mode: 'copy'
  input:
    file trace from ch_trace
  output:
    file trace_table_csv

  script:
  trace_table_csv = "trace.csv"
  """
  make_trace_table.py -t $trace -o $trace_table_csv 
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



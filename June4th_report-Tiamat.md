# Process Log: STARsolo Alignment — Stellarscope Protocol

**Date:** 2026-06-04  
**Author:** Alejandra Paulina Perez Gonzalez  

---

## Starting Knowledge

Before this session, I had theoretical familiarity with single-cell RNA-seq workflows. 
The Stellarscope pipeline concept (STAR alignment → Stellarscope TE quantification) is quite new for me.
I had not previously run STAR, submitted a SLURM job, or worked hands-on with the SRA Toolkit or
NeMO Archive downloads.
I knew that R1 carries the cell barcode + UMI and R2 carries the cDNA read.

What I did not know going in:
- How SLURM scripts are structured and what each `#SBATCH` directive controls
- What resource requirements (memory, CPUs, time) STAR alignment actually needs and why
- How the Stellarscope protocol modifies standard STAR parameters to retain multimappers
- The difference between `--readFilesIn` argument order in STARsolo vs standard STAR
  (cDNA read first, then barcode+UMI read — opposite of what I expected)

---

## Context: Why We Did Not Use SRA Toolkit / prefetch

The Stellarscope protocol (Liotta et al. 2025) instructs users to download raw FASTQ files
from SRA using `prefetch` and `parallel-fastq-dump`. On our server (CentOS), this approach
failed immediately with a GLIBC version incompatibility:

```
sra-stat: /lib64/libm.so.6: version `GLIBC_2.27' not found (required by sra-stat)
```

The same error blocked `parallel-fastq-dump`. This is a known issue with conda-distributed
SRA Toolkit binaries on older Linux distributions: the conda binary is compiled against a
newer glibc than what is available on the system.

**Resolution:** Ian had already obtained the FASTQ files, reference genome index, TE
annotation, and barcode whitelist through independent means. He created a shared directory
and we created symlinks from our working directory (`~/stellarscope_protocol/`) to those
resources, bypassing the download step entirely. The files used are:

| Resource | Path |
|---|---|
| FASTQ files (R1 + R2, 2 runs) | `results/fastq/hSAT/SRR3127793{6,7}_{1,2}.fastq.gz` |
| STAR genome index (GRCh38, GENCODE v43) | `resources/reference_genome/star/` |
| 10x v3 barcode whitelist | `resources/whitelist/3M-february-2018.txt` |
| TE annotation (retro.hg38.v1) | `resources/te_annotation/retro.hg38.v1.gtf` |

---

## Step Executed: STAR Alignment with STARsolo

### What STAR is doing

STAR aligns RNA-seq reads to the reference genome, producing a coordinate-sorted BAM
file. The BAM contains all aligned reads including multimappers. The STARsolo module
simultaneously performs cell barcode and UMI assignment, so the output also includes a
gene-level count matrix (equivalent to Cell Ranger output) without any additional tools.

The key reason STAR needs large memory (~40–60 GB for the human genome) is that it loads
the entire genome index into RAM before alignment begins. This is a one-time cost per run
that enables extremely fast per-read lookup during alignment.

For Stellarscope specifically, STAR must be run with modified parameters that **retain
multimapping reads** — reads that align to multiple genomic locations. Standard pipelines
discard these, but they contain essential TE expression signal. Stellarscope's probabilistic
model then resolves which locus each multimapper most likely originated from.

### SLURM script submitted

```bash
#!/bin/bash
#SBATCH --job-name=star_hSAT
#SBATCH --output=logs/slurm/star_hSAT_%j.out
#SBATCH --error=logs/slurm/star_hSAT_%j.err
#SBATCH --time=12:00:00
#SBATCH --mem=0
#SBATCH --cpus-per-task=16
#SBATCH --nodes=1
#SBATCH --ntasks=1

set -euo pipefail

mkdir -p results/star_alignment_multi/hSAT
mkdir -p logs/slurm

STAR \
  --runThreadN "${SLURM_CPUS_PER_TASK}" \
  --genomeDir resources/reference_genome/star \
  --readFilesIn \
    results/fastq/hSAT/SRR31277936_2.fastq.gz,results/fastq/hSAT/SRR31277937_2.fastq.gz \
    results/fastq/hSAT/SRR31277936_1.fastq.gz,results/fastq/hSAT/SRR31277937_1.fastq.gz \
  --readFilesCommand gunzip -c \
  --soloCBwhitelist resources/whitelist/3M-february-2018.txt \
  --soloType CB_UMI_Simple \
  --soloCBstart 1 --soloCBlen 16 \
  --soloUMIstart 17 --soloUMIlen 12 \
  --outSAMattributes NH HI AS nM MD CR CY UR UY CB UB GX GN sS sQ sM \
  --outSAMtype BAM SortedByCoordinate \
  --outFilterScoreMin 30 \
  --outFilterMultimapNmax 200 \
  --outFilterMultimapScoreRange 5 \
  --soloCellFilter EmptyDrops_CR \
  --outFileNamePrefix results/star_alignment_multi/hSAT/ \
  --outTmpDir results/star_alignment_multi/hSAT/_STARtmp
```

### Key parameter annotations

| Parameter | Value | Why |
|---|---|---|
| `--runThreadN` | 16 (from `$SLURM_CPUS_PER_TASK`) | Parallelizes alignment across CPU cores |
| `--mem=0` | all available node memory | Ensures STAR can load the full genome index; `0` requests all memory on the node |
| `--readFilesIn` | R2 first, then R1 | STARsolo requires cDNA read first, barcode+UMI second — opposite of file naming convention |
| `--readFilesCommand gunzip -c` | — | FASTQs are gzip-compressed; STAR decompresses on the fly |
| `--soloType CB_UMI_Simple` | — | 10x Genomics single-cell mode |
| `--soloCBlen 16` / `--soloUMIlen 12` | — | 10x v3 chemistry: 16 bp CB + 12 bp UMI |
| `--soloCBwhitelist` | 3M-february-2018.txt | Restricts valid barcodes to the 10x v3 whitelist (~6.7M barcodes) |
| `--outFilterMultimapNmax 200` | — | **Stellarscope-critical**: allows reads to map up to 200 locations (default is 20); required to capture TE reads |
| `--outFilterMultimapScoreRange 5` | — | **Stellarscope-critical**: retains alternative alignments within 5 points of the best score, preserving mapping ambiguity for probabilistic reassignment |
| `--outSAMattributes ... GX GN ...` | — | **Stellarscope-critical**: includes gene ID tags and multimapping tags required for TE reassignment |
| `--soloCellFilter EmptyDrops_CR` | — | Cell Ranger-compatible cell calling algorithm |
| `--outFilterScoreMin 30` | — | Minimum alignment score; filters low-quality alignments |
| `--outSAMtype BAM SortedByCoordinate` | — | Output is a coordinate-sorted BAM, required for `stellarscope cellsort` in the next step |

### SLURM concepts learned

SLURM is a job scheduler. You do not run commands directly on the entry server; instead
you write a shell script with `#SBATCH` header directives that declare your resource
requirements, then submit it with `sbatch`. SLURM queues the job and farms it to a compute
node with the requested resources available. The entry server is freed immediately; the job
runs in the background.

Key `#SBATCH` directives used:

- `--job-name`: label visible in `squeue`
- `--output` / `--error`: where stdout and stderr are written (`%j` = job ID)
- `--time`: wall-clock time limit; job is killed if it exceeds this
- `--mem=0`: request all available memory on the assigned node
- `--cpus-per-task`: number of CPU cores allocated; passed to STAR via `$SLURM_CPUS_PER_TASK`
- `--nodes=1` / `--ntasks=1`: single-node, single-task job (appropriate for STAR which handles its own threading)

### Job submission

```bash
sbatch slurm_STARsolo_stellarscopeprotocol.sh
```

Job submitted successfully. Status can be monitored with:

```bash
squeue -u $USER
tail -f logs/slurm/star_hSAT_<JOBID>.out
```

**Status as of 2026-06-04:** Job is currently running.

---

## Expected Outputs (pending job completion)

Once STAR finishes, the following should be present under `results/star_alignment_multi/hSAT/`:

| File / Directory | Contents |
|---|---|
| `Aligned.sortedByCoord.out.bam` | Coordinate-sorted BAM with all alignments including multimappers |
| `Log.final.out` | Summary alignment statistics (mapping rate, number of reads, etc.) |
| `Log.out` | Full run log |
| `Log.progress.out` | Progress updates written during the run |
| `SJ.out.tab` | Splice junction table |
| `Solo.out/Gene/filtered/` | STARsolo gene count matrix (barcodes.tsv, features.tsv, matrix.mtx) |
| `Solo.out/Gene/raw/` | Unfiltered count matrix |

The `Solo.out/Gene/filtered/barcodes.tsv` file is also a required input for `stellarscope cellsort` in the next step.

---

## Next Steps

1. Verify job completed successfully: check `Log.final.out` for mapping rate and `Log.out` for errors
2. Run `stellarscope cellsort` to sort the BAM by cell barcode
3. Run `stellarscope assign --pooling_mode pseudobulk`
4. Run `stellarscope resolve` to remove UMI conflicts between TEs and canonical genes
5. Run `stellarscope merge` to produce the unified gene + TE count matrix
6. Load merged matrix into R/Seurat

---

## Open Questions

- What mapping rate is acceptable for snRNA-seq data from this tissue type?
- `--mem=0` requests all node memory — is this appropriate for a shared cluster, or should we specify a value (e.g., 60G)?
- The protocol uses `--soloCellFilter EmptyDrops_CR` but our Siletti data was originally processed with Cell Ranger. Will the cell calls be consistent with the published barcodes?
- For the full herv-brain-atlas pipeline (606 samples), what is the expected per-sample runtime at 16 CPUs to plan batch scheduling?

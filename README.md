# Stellarscope Protocol — Training Repository

**Authors:** Ian Marston & Paulina Gonzalez Perez  
**Supervisor:** Helena Reyes-Gopar  
**Date:** June 2026  
**Reference protocol:** Liotta et al. (2025), STAR Protocols — *Quantifying locus-specific transposable element transcripts in single-cell RNA-seq data with Stellarscope*

---

## Objective

This repository documents our collaborative work running the Stellarscope protocol for
quantifying transposable element (TE) expression from single-cell RNA-seq data. The
immediate goal is to successfully execute the full STARsolo + Stellarscope pipeline on a
publicly available snRNA-seq dataset (human subcutaneous adipose tissue, donor 3399),
understand every step of the process, and produce documented, reproducible outputs.

This is a training exercise in preparation for running the same pipeline at scale on
~606 samples from the Siletti et al. 2023 Adult Human Brain Atlas
(DOI: 10.1126/science.add7046).

---

## Assignment

The following instructions were given by Helena Reyes-Gopar:

> Hi Ian and Paulina,
>
> Today I'd like you to work through the Stellarscope protocol together so Paulina can get
> up to speed before running her own single-cell RNA-seq dataset. Ian, you have been
> working with the Protocol, so you can tell Paulina what you've learned so far, but I want
> you both to work together on running it.
>
> Please make sure you both have clear understanding of:
>
> - **Protocol steps:** what's the complete workflow?
> - **Inputs and outputs:** what files go in, what comes out of each step? What are they?
>   - FASTQ files: examine both R1 and R2 files from the same pair: Where did they
>     originate? Look at the first lines of each, compare their lengths, why are they
>     different?
> - **The alignment command, how is it constructed?**
>   - What is STAR, and what's it doing?
>   - What do the parameters mean and why are they set the way they are?
>
> Now, Ian has already tried the alignment step, and I want you two to figure out what
> happened, check the output of the command line, what is it telling you? Check the log
> files, what is reported in there?
>
> Once you've covered those, figure out together how to run the alignment on the AWS
> server using SLURM.
>
> Here is some information about SLURM and the cluster setup:
> When we work in the projects directory, we're actually on the entry server, so the
> gateway to our compute cluster. The entry server is intentionally small and fast for
> interactive work like file management and script editing, but it's not meant for intensive
> computational jobs. The real compute power lives on compute nodes: separate machines
> across the cluster that are connected and managed by SLURM.
>
> SLURM is essentially a job scheduler and resource manager. Instead of trying to run your
> alignment command directly on the entry server (which would overload it), you write a
> SLURM script that says: "Here's a job I want to run. Here's how much memory it needs,
> how many CPUs, how long it might take." You then submit that script to SLURM, which
> reads your request and finds an available compute node with the resources you asked for,
> then runs your job there. You get back to the entry server immediately — your job runs
> in the background.
>
> So the workflow is: you're on the entry server in projects, you craft your alignment
> command in a script, you submit it to SLURM with `sbatch` (or similar), and SLURM farms
> it out to one of the compute nodes. The nodes are all networked together, so they can all
> access the same shared storage where your FASTQ files and reference genome live. Once
> the job finishes, the output files are waiting for you whenever you're ready to keep
> working.
>
> **Primary aims:**
>
> 1. **Run the alignment and generate outputs:** your immediate goal is to produce a BAM
>    file and the STARsolo outputs (gene count matrices, BAM file — document what the
>    outputs are and what's in them) for one sample using the Stellarscope protocol via
>    SLURM.
>
> 2. **Understand SLURM fundamentally:** Figure out together how to actually communicate
>    with the cluster:
>    - Do you wrap commands with SLURM (i.e. is it a command?), or do you create a file
>      to submit?
>    - How exactly is a job request structured? What information about your job/command
>      do you need to have?
>    - What are the `#SBATCH` directives and what do they do?
>    - How do you actually send a job to run?
>    - **Learn resource allocation:** Recognize that different jobs require different compute
>      resources (memory, CPUs, runtime). For alignment, discuss: How much memory does
>      STAR need? What is it for? (high level explanation — what task is STAR doing? it's
>      one main thing.) How many CPUs can it use? Can you know how long it will take?
>      Does it always take the same time? Or does this change depending on the resources
>      you request? How do you translate these into SLURM parameters?
>
> 3. **Document everything:** create a GitHub repository (one you both have access to) and
>    document this process. Create a markdown file with your notes:
>    - What was your starting knowledge and what didn't you know?
>    - What did you do step-by-step?
>    - What did you learn? What questions remain?
>
>    One of you will type/run the commands; the other will actively document what's
>    happening in real time. You can switch at any time, but this is collaborative — talk
>    through every step together. Run the alignment once (you only need one successful
>    example), but make sure both of you understand every part of the process.

---

## Pipeline Overview

The Stellarscope workflow from raw reads to integrated gene + TE count matrix:

```
FASTQ files (R1: CB+UMI, R2: cDNA)
        |
        v
  STAR alignment (STARsolo)
  -- retains multimapping reads (--outFilterMultimapNmax 200)
  -- produces coordinate-sorted BAM + gene count matrix
        |
        v
  stellarscope cellsort
  -- re-sorts BAM by cell barcode for efficient per-cell processing
        |
        v
  stellarscope assign
  -- probabilistic reassignment of multimappers to TE loci (EM algorithm)
  -- produces TE count matrix per cell
        |
        v
  stellarscope resolve
  -- removes UMI conflicts between TEs and canonical genes
  -- canonical genes take priority
        |
        v
  stellarscope merge
  -- concatenates gene counts (STARsolo) + TE counts (Stellarscope)
  -- produces unified count matrix (genes + TEs)
        |
        v
  Downstream analysis (R / Seurat)
```

---

## Repository Structure

```
stellarscope_protocol/
├── README.md                          # this file
├── logs/
│   └── slurm/                         # SLURM stdout/stderr logs
├── resources/
│   ├── reference_genome/star/         # pre-built STAR index (GRCh38, GENCODE v43)
│   ├── te_annotation/                 # retro.hg38.v1.gtf (Bendall et al.)
│   └── whitelist/                     # 10x v3 barcode whitelist (3M-february-2018.txt)
├── results/
│   ├── fastq/hSAT/                    # FASTQ files (symlinked from shared directory)
│   ├── star_alignment_multi/hSAT/     # STAR outputs
│   ├── stellarscope/hSAT/             # Stellarscope outputs
│   └── downstream/                    # Seurat objects and downstream analysis
├── workflow/
│   └── scripts/
│       └── downstream_analysis.Rmd    # R downstream analysis script
├── slurm_STARsolo_stellarscopeprotocol.sh   # SLURM job script for STAR alignment
└── docs/
    └── process_log_STARsolo_alignment.md    # step-by-step process log
```

---

## Data

**Sample:** human subcutaneous adipose tissue, donor 3399 (hSAT)  
**SRA accessions:** SRR31277936, SRR31277937  
**Original study:** Lazarescu et al. (2025), *Nature Genetics* 57:413–426  
**GEO:** GSM8619173

**Reference genome:** GRCh38 with GENCODE v43 annotations  
(Broad Institute WARP pipelines pre-built STAR index)

**TE annotation:** retro.hg38.v1 (LINEs + HERVs for human GRCh38)  
Source: https://github.com/mlbendall/telescope_annotation_db

**Barcode whitelist:** 10x Genomics Chromium Single Cell 3' v3 chemistry  
(3M-february-2018.txt)

> **Note on data access:** The FASTQ files, genome index, TE annotation, and whitelist were
> provided via a shared directory by Ian Marston. Symlinks point from `resources/` and
> `results/fastq/` to the shared location. The SRA Toolkit download approach described in
> the original protocol could not be used due to a GLIBC version incompatibility on the
> cluster (`GLIBC_2.27` not found on CentOS). See the process log for details.

---

## Environment

This protocol uses the conda environment from the Stellarscope STAR protocol repository:

```bash
# Clone the original protocol repo to get the environment file
git clone https://github.com/nixonlab/stellarscope_STAR_protocol.git

# Create environment
conda env create -f stellarscope_STAR_protocol/workflow/envs/stellarscope_STAR_protocol.yaml

# Activate
conda activate stellarscope_protocol
```

Key software versions:
- STAR 2.7.11b
- Stellarscope 1.5
- R 4.3.1
- Seurat 5.3.0

---

## Running the Pipeline

### Step 1 — STAR alignment (SLURM)

```bash
sbatch slurm_STARsolo_stellarscopeprotocol.sh
```

Monitor:
```bash
squeue -u $USER
tail -f logs/slurm/star_hSAT_<JOBID>.out
```

### Step 2 — Stellarscope cellsort

```bash
stellarscope cellsort \
  --nproc 16 \
  --tempdir /tmp \
  --outfile results/stellarscope/hSAT/Aligned.sortedByCB.bam \
  results/star_alignment_multi/hSAT/Aligned.sortedByCoord.out.bam \
  results/star_alignment_multi/hSAT/Solo.out/Gene/filtered/barcodes.tsv
```

### Step 3 — Stellarscope assign

```bash
stellarscope assign \
  --exp_tag pseudobulk \
  --outdir results/stellarscope/hSAT \
  --nproc 16 \
  --pooling_mode pseudobulk \
  --stranded_mode F \
  --updated_sam \
  results/stellarscope/hSAT/Aligned.sortedByCB.bam \
  resources/te_annotation/retro.hg38.v1.gtf \
  --logfile results/stellarscope/hSAT/pseudobulk_assign.log
```

### Step 4 — Stellarscope resolve

```bash
stellarscope resolve --exp_tag pseudobulk results/stellarscope/hSAT
```

### Step 5 — Stellarscope merge

```bash
stellarscope merge \
  --exp_tag pseudobulk \
  results/star_alignment_multi/hSAT/Solo.out/Gene/filtered/ \
  results/stellarscope/hSAT/
```

### Step 6 — Downstream analysis (R)

```bash
Rscript -e 'rmarkdown::render("workflow/scripts/downstream_analysis.Rmd",
            output_dir = "results/downstream/")'
```

---

## Documentation

Detailed step-by-step notes, including what we knew going in, what we did, what we
learned, and open questions, are in:

`docs/process_log_STARsolo_alignment.md`

---

## References

- Liotta N, Nixon DF, Marston JL, Bendall ML, Reyes-Gopar H (2025). Quantifying
  locus-specific transposable element transcripts in single-cell RNA-seq data with
  Stellarscope. *STAR Protocols*.
- Reyes-Gopar H, Marston JL et al. (2025). A single-cell transposable element atlas of
  human cell identity. *Cell Reports Methods* 5:101086.
- Lazarescu O et al. (2025). Human subcutaneous and visceral adipocyte atlases uncover
  classical and nonclassical adipocytes and depot-specific patterns. *Nature Genetics*
  57:413–426.
- Siletti K et al. (2023). Transcriptomic diversity of cell types across the adult human
  brain. *Science* 382:eadd7046.

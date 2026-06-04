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

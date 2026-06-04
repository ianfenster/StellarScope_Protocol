#!/bin/bash
#SBATCH --job-name=stellarscope_cellsort_hSAT
#SBATCH --output=logs/slurm/stellarscope_cellsort_hSAT_%j.out
#SBATCH --error=logs/slurm/stellarscope_cellsort_hSAT_%j.err
#SBATCH --time=06:00:00
#SBATCH --mem=0
#SBATCH --cpus-per-task=16
#SBATCH --nodes=1
#SBATCH --ntasks=1

set -euo pipefail

mkdir -p results/stellarscope/hSAT

stellarscope cellsort \
  --nproc "${SLURM_CPUS_PER_TASK}" \
  --tempdir /tmp \
  --outfile results/stellarscope/hSAT/Aligned.sortedByCB.bam \
  results/star_alignment_multi/hSAT/Aligned.sortedByCoord.out.bam \
  results/star_alignment_multi/hSAT/Solo.out/Gene/filtered/barcodes.tsv

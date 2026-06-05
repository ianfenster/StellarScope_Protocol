#!/bin/bash
#SBATCH --job-name=stellarscope_assign_hSAT
#SBATCH --output=logs/slurm/stellarscope_assign_hSAT_%j.out
#SBATCH --error=logs/slurm/stellarscope_assign_hSAT_%j.err
#SBATCH --time=12:00:00
#SBATCH --mem=0
#SBATCH --cpus-per-task=16
#SBATCH --nodes=1
#SBATCH --ntasks=1

set -euo pipefail

stellarscope assign \
  --exp_tag pseudobulk \
  --outdir results/stellarscope/hSAT \
  --nproc "${SLURM_CPUS_PER_TASK}" \
  --pooling_mode pseudobulk \
  --stranded_mode F \
  --updated_sam \
  results/stellarscope/hSAT/Aligned.sortedByCB.bam \
  resources/te_annotation/retro.hg38.v1.gtf \
  --logfile results/stellarscope/hSAT/pseudobulk_assign.log

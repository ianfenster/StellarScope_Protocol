#!/bin/bash
#SBATCH --job-name=stellarscope_resolve_hSAT
#SBATCH --output=logs/slurm/stellarscope_resolve_hSAT_%j.out
#SBATCH --error=logs/slurm/stellarscope_resolve_hSAT_%j.err
#SBATCH --time=06:00:00
#SBATCH --mem=0
#SBATCH --cpus-per-task=4
#SBATCH --nodes=1
#SBATCH --ntasks=1

set -euo pipefail

stellarscope resolve \
  --exp_tag pseudobulk \
  results/stellarscope/hSAT

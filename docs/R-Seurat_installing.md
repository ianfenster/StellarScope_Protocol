# Installing R 4.3.1 and Seurat 5.3.0 in the `stellarscope_protocol` conda environment

**Date:** 5th June 2026  

---

## Context

The `stellarscope_protocol` conda environment is the main computational environment in the STAR Stellarscope protocol.
R version ≥4.0 is required, Seurat version ≥5 is required
R is used for metadata preparation, sample table construction. Seurat is required for single-cell RNA-seq data handling and downstream analysis.
R is installed via `conda-forge` rather than the system to avoid GLIBC compatibility issues in the server.

---

## Prerequisites

- conda installed and initialized (`conda init bash` or equivalent)

---

## Step 1 — Activate the environment

```bash
conda activate stellarscope_protocol

```

---

## Step 2 — Install R 4.3.1 via conda-forge

```bash
conda install -c conda-forge r-base=4.3.1 -y
```

Verify the installation:

```bash
R --version
# Expected output: R version 4.3.1 (2023-06-16)
```

---

## Step 3 — Install system-level dependencies via conda

These libraries are required to compile Seurat dependencies. Installing them via conda avoids needing root access and resolves HPC GLIBC constraints.

```bash
conda install -c conda-forge \
  libgfortran-ng \
  gsl \
  hdf5 \
  pkg-config \
  libxml2 \
  -y
```

---

## Step 4 — Install Seurat 5.3.0 from within R

Open R inside the activated environment:

```bash
R
```

Then run the following installation commands:

```r
# Install BiocManager (required for Bioconductor dependencies)
install.packages("BiocManager", repos = "https://cloud.r-project.org")

# Install Bioconductor dependencies
BiocManager::install(
  c(
    "BiocGenerics",
    "S4Vectors",
    "GenomicRanges",
    "SingleCellExperiment",
    "SummarizedExperiment"
  ),
  update = FALSE,
  ask = FALSE
)

# Install Seurat 5.3.0
# Option A: from CRAN (if 5.3.0 is the current version)
install.packages("Seurat", repos = "https://cloud.r-project.org")

# Option B: pin to exact version using remotes (preferred for reproducibility)
install.packages("remotes")
remotes::install_version("Seurat", version = "5.3.0", repos = "https://cloud.r-project.org")

# Verify
packageVersion("Seurat")
# Expected: [1] '5.3.0'
```

---

## Step 5 — Export the updated environment

After confirming the installation, export the environment for reproducibility (THIS IS ONLY FOR THIS PROTOCOL PURPOSES, THIS WILL NOT BE PUSHED TO THE PUBLIC REPO):

```bash
conda env export > workflow/envs/stellarscope_protocol-1.yaml
```

---

## Known issues and solutions

| Issue | Cause | Fix |
|---|---|---|
| `GLIBC_2.xx not found` | System R uses host glibc | Use conda-forge R (this procedure) — conda bundles its own glibc |
| HDF5 errors on `SeuratDisk` | Missing HDF5 library | Install `hdf5` via conda before entering R (Step 3) |
| `rgeos` or `sf` fail to compile | Geospatial libs missing | Not required for Seurat core; skip safely |
| CRAN only has newer Seurat | Version drift | Use `remotes::install_version()` to pin to 5.3.0 |
| `curl` or `openssl` errors | SSL mismatch between conda and system | Install `r-curl` and `openssl` via conda-forge before opening R |

---

## Open questions

- Seurat 5 requires `SeuratObject >= 5.0.0` — confirm this is installed as a dependency automatically.
- Integration with STARsolo count matrices (`.mtx` / `filtered_feature_bc_matrix/`) uses `Read10X()` from Seurat — no additional dependencies required.

---

## References

- Seurat v5 documentation: https://satijalab.org/seurat/
- conda-forge R packages: https://conda-forge.org/

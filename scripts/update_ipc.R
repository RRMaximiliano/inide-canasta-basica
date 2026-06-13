# Refresh the cached monthly IPC (consumer price index) series.
# Fetches the latest IMF IFS monthly CPI for Nicaragua (via DBnomics) and
# rewrites data/ipc_nicaragua.csv. Falls back to the existing cache on failure.
# NOTE: run from the repository root, e.g. Rscript scripts/update_ipc.R

suppressPackageStartupMessages({
  library(dplyr); library(stringr); library(tibble)
  library(readr); library(jsonlite)
})

source("R/ipc.R")

ipc <- load_ipc(cache_path = "data/ipc_nicaragua.csv", refresh = TRUE)
cat(sprintf("IPC series: %d months, %s -> %s (base 2010 = 100)\n",
            nrow(ipc), as.character(min(ipc$ym)), as.character(max(ipc$ym))))

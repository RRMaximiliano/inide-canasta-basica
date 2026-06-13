# Quick fix script to repair the CB_FULL dataset.
# Re-compiles the existing RAW data (data/CB_FULL_raw.rds) with the shared
# compilation pipeline (clean + categories + real prices).
# NOTE: run from the repository root, e.g. Rscript scripts/fix_data.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(forcats)
  library(lubridate)
  library(stringr)
  library(tibble)
  library(haven)
  library(glue)
  library(jsonlite)
})

# Cleaning / categories / real prices come from the single shared source.
source("R/compile_canasta.R")

cat("Loading raw data...\n")
raw_data <- readRDS("data/CB_FULL_raw.rds")
cat("Columns:", paste(names(raw_data), collapse = ", "), "\n")

cat("Compiling (clean + categories + real prices)...\n")
cleaned_data <- compile_canasta(raw_data)

cat("After compiling:\n")
cat("Columns:", paste(names(cleaned_data), collapse = ", "), "\n")
cat("Rows with NA in good column:", sum(is.na(cleaned_data$good)), "\n")
cat("Rows with NA in categoria column:", sum(is.na(cleaned_data$categoria)), "\n")

# Save the corrected data (writers match the pipeline: base write.csv)
cat("\nSaving corrected datasets...\n")
write.csv(cleaned_data, "data/CB_FULL.csv", row.names = FALSE)
write_rds(cleaned_data, "data/CB_FULL.rds")
write_dta(cleaned_data, "data/CB_FULL.dta")

cat("\nData successfully repaired!\n")
month_levels <- c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
                  "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")
latest <- cleaned_data[order(cleaned_data$year,
                             match(as.character(cleaned_data$month), month_levels)), ]
cat("Latest data point:", tail(latest$year, 1),
    as.character(tail(latest$month, 1)), "\n")

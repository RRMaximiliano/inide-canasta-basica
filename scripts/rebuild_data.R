# Rebuild CB_FULL from the individual monthly files.
# Reads every data/monthly/*.csv, compiles with the shared pipeline
# (clean + categories + real prices), and rewrites the raw + cleaned datasets.
# NOTE: run from the repository root, e.g. Rscript scripts/rebuild_data.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
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

cat("Rebuilding CB_FULL from monthly files...\n")
monthly_files <- list.files("data/monthly", pattern = "^CB.*\\.csv$",
                            full.names = TRUE)
cat("Found", length(monthly_files), "monthly files\n")

all_data <- map_df(monthly_files, function(file) {
  read_csv(file, show_col_types = FALSE)
})
cat("Combined", nrow(all_data), "rows from monthly files\n")
cat("Columns:", paste(names(all_data), collapse = ", "), "\n")

cat("\nCompiling (clean + categories + real prices)...\n")
cleaned_data <- compile_canasta(all_data)
cat("Columns after compiling:", paste(names(cleaned_data), collapse = ", "), "\n")
cat("Rows with NA in good column:", sum(is.na(cleaned_data$good)), "\n")
cat("Rows with NA in categoria column:", sum(is.na(cleaned_data$categoria)), "\n")

# Save the raw version (before cleaning) and the cleaned version
cat("\nSaving datasets...\n")
write.csv(all_data, "data/CB_FULL_raw.csv", row.names = FALSE)
write_rds(all_data, "data/CB_FULL_raw.rds")
write.csv(cleaned_data, "data/CB_FULL.csv", row.names = FALSE)
write_rds(cleaned_data, "data/CB_FULL.rds")
write_dta(cleaned_data, "data/CB_FULL.dta")

cat("\nData successfully rebuilt from monthly files!\n")
cat("Total rows:", nrow(cleaned_data), "\n")
cat("Date range:", min(cleaned_data$year), "-", max(cleaned_data$year), "\n")

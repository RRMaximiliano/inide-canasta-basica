# Utility Scripts

This folder contains utility scripts for maintenance and troubleshooting purposes.

All scripts must be run from the repository root (they use relative paths and
`source("R/compile_canasta.R")`).

The compilation logic itself lives in `R/` (single source of truth):
- `R/clean_canasta_data.R` — name/structure cleaning and standardization
- `R/categories.R` — maps the 53 goods to INIDE's 3 official groups
- `R/ipc.R` — fetches the monthly IPC and computes real (deflated) prices
- `R/compile_canasta.R` — composes the three into `compile_canasta()`

## Scripts

### `validate_data.R`
Hard validation of the cleaned dataset. Exits non-zero on any failure.
Runs automatically in CI after every scrape; can be run manually anytime.
Checks row counts, month contiguity, NA, the `total = cantidad * precio`
identity, the 3-category split, and the real-price columns.

**When to use:**
- Runs automatically in GitHub Actions on every pipeline run
- After any manual data repair (`fix_data.R`, `rebuild_data.R`)

**Usage:**
```r
Rscript scripts/validate_data.R
```

### `rebuild_data.R`
Rebuilds the full `CB_FULL` dataset from all monthly CSV files in `data/monthly/`.

**When to use:**
- If the main dataset gets corrupted
- If you need to reprocess all historical data with updated cleaning rules
- After making changes to anything under `R/`

**Usage:**
```r
Rscript scripts/rebuild_data.R
```

### `fix_data.R`
Repairs the `CB_FULL` dataset by recompiling the existing raw data
(`data/CB_FULL_raw.rds`) with the shared pipeline.

**When to use:**
- Quick fix for data issues without rebuilding from monthly files
- After changing a cleaning/category/deflation rule in `R/`

**Usage:**
```r
Rscript scripts/fix_data.R
```

### `update_ipc.R`
Refreshes the cached monthly IPC series (`data/ipc_nicaragua.csv`) used for
real prices. Source: IMF IFS monthly CPI for Nicaragua (base 2010 = 100), via
the DBnomics API. Falls back to the existing cache if the fetch fails.

**Usage:**
```r
Rscript scripts/update_ipc.R
```

### `check_data.R`
Diagnostic script to verify data integrity and check for issues (print-only,
does not fail). For automated checks prefer `validate_data.R`.

**Usage:**
```r
Rscript scripts/check_data.R
```

## Note

The main data processing runs in GitHub Actions via `02_scrape_auto.R`, which
sources the same `R/` modules. These utility scripts share that logic and are
kept for manual rebuilds and troubleshooting.

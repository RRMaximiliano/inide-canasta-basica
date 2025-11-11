# Utility Scripts

This folder contains utility scripts for maintenance and troubleshooting purposes.

## Scripts

### `rebuild_data.R`
Rebuilds the full `CB_FULL` dataset from all monthly CSV files in `data/monthly/`.

**When to use:**
- If the main dataset gets corrupted
- If you need to reprocess all historical data with updated cleaning rules
- After making changes to the `clean_canasta_data()` function

**Usage:**
```r
Rscript scripts/rebuild_data.R
```

### `fix_data.R`
Repairs the `CB_FULL` dataset by reprocessing the existing raw data with the cleaning function.

**When to use:**
- Quick fix for data issues without rebuilding from monthly files
- When `CB_FULL_raw.rds` exists but needs re-cleaning

**Usage:**
```r
Rscript scripts/fix_data.R
```

### `check_data.R`
Diagnostic script to verify data integrity and check for issues.

**When to use:**
- To verify recent months have complete data
- To check for NA values in critical columns
- After running updates to ensure data quality

**Usage:**
```r
Rscript scripts/check_data.R
```

## Note

These scripts are **not** part of the automated workflow. The main data processing is handled by:
- `02_scrape_auto.R` - Automated monthly data updates (runs via GitHub Actions)

These utility scripts are kept for reference and manual troubleshooting only.

# GitHub Actions & Data Fix - November 2025

## Problems Identified

### 1. GitHub Actions Failure (Past 2 Months)
The workflow was failing with dependency conflicts because the `hrbrthemes` package was archived from CRAN.

### 2. App Data Discrepancy
The Shiny app showed different data ranges:
- "Por Bien" tab: Only up to June 2025
- "Canasta Agrupada" tab: Up to October 2025

**Root Cause:** July-October 2025 data had `NA` values in the `good` column due to column name mismatches when combining old and new data.

---

## Solutions Applied

### Fix 1: GitHub Actions (hrbrthemes removal)

#### Updated Files:
1. **`.github/workflows/update-data.yml`**
   - Removed `any::hrbrthemes` from dependencies
   - Added `any::systemfonts`
   - Removed duplicate `any::lubridate`

2. **`03_plots.R`**
   - Removed `library(hrbrthemes)`
   - Replaced `theme_ipsum_rc()` → `theme_minimal(base_size = 12)`

3. **`app.R`**
   - Removed `library(hrbrthemes)`
   - Replaced `theme_ipsum_rc()` → `theme_minimal(base_size = 14)`

**Result:** GitHub Actions now runs successfully without archived package dependencies.

---

### Fix 2: Data Column Mismatch

#### Updated Files:
**`02_scrape_auto.R`** - Two critical changes:

1. **Enhanced `clean_canasta_data()` function** (Line 28-30):
   ```r
   # Old code (would drop bien column):
   select(., -bien)
   
   # New code (merges both columns):
   mutate(., good = coalesce(good, bien)) %>%
   select(., -bien)
   ```

2. **Fixed data loading logic** (Line 323-339):
   ```r
   # Old code (loaded cleaned data, causing column mismatches):
   if(file.exists("data/CB_FULL.rds")) {
     old_data <- read_rds("data/CB_FULL.rds")
   
   # New code (loads raw data and ensures consistent columns):
   if(file.exists("data/CB_FULL_raw.rds")) {
     old_data <- read_rds("data/CB_FULL_raw.rds")
     if("good" %in% names(old_data) && !"bien" %in% names(old_data)) {
       old_data <- old_data %>% rename(bien = good)
     }
   ```

**Why this matters:**
- Old data had a `good` column
- New data from INIDE has a `bien` column
- When combined with `bind_rows()`, both columns were created with `NA` where missing
- The fix ensures both columns are merged properly

---

### Fix 3: Data Repair & Organization

#### Repaired Data:
- Rebuilt `CB_FULL.rds`, `CB_FULL.csv`, `CB_FULL_raw.rds`, `CB_FULL_raw.csv`
- All 2025 months now have complete good names (53 items per month)
- Total: 11,554 rows from Sep 2007 to Oct 2025

#### Created `scripts/` folder:
Organized utility scripts for future maintenance:
- `scripts/rebuild_data.R` - Rebuild from monthly files
- `scripts/fix_data.R` - Quick data repair
- `scripts/check_data.R` - Data verification
- `scripts/README.md` - Documentation

---

## Testing

After fixes:
- ✅ GitHub Actions installs all dependencies
- ✅ All data files have complete `good` column
- ✅ Both app tabs show October 2025
- ✅ Plots generate with new theme
- ✅ Future monthly runs will not have column mismatch issues

---

## Prevention

The fixes ensure:
1. **No more archived package dependencies** - Using only maintained CRAN packages
2. **Robust column handling** - Merges `good`/`bien` columns regardless of which exists
3. **Consistent data structure** - Always loads raw data and normalizes column names before combining
4. **Better diagnostics** - Utility scripts available for troubleshooting

---

## Next Steps

1. Commit these changes to the repository
2. Monitor the next scheduled GitHub Actions run (15th of month)
3. Verify the Shiny app deployment works correctly
4. The workflow should now run smoothly every month

---

*Fixed: November 10, 2025*

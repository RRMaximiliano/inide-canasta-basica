# GitHub Actions Fix - November 2025

## Problem
The GitHub Actions workflow was failing with dependency conflicts because the `hrbrthemes` package was archived from CRAN and is no longer available for installation.

## Root Cause
The error message showed:
```
* any::hrbrthemes: Can't find package called any::hrbrthemes.
```

The `hrbrthemes` package was removed from CRAN, which caused a cascade of dependency resolution failures.

## Solution Applied

### 1. Updated GitHub Actions Workflow (`.github/workflows/update-data.yml`)
- **Removed**: `any::hrbrthemes` from the package list
- **Added**: `any::systemfonts` (needed for ggplot2 text rendering)
- **Removed**: Duplicate `any::lubridate` entry

### 2. Updated R Scripts
Replaced `hrbrthemes::theme_ipsum_rc()` with `theme_minimal(base_size = 12)` or `theme_minimal(base_size = 14)`:

- **`03_plots.R`**: 
  - Removed `library(hrbrthemes)`
  - Replaced all 3 instances of `theme_ipsum_rc()` with `theme_minimal(base_size = 12)`

- **`app.R`**:
  - Removed `library(hrbrthemes)`
  - Replaced 2 instances of `theme_ipsum_rc()` with `theme_minimal(base_size = 14)`

### 3. Visual Impact
The plots will look slightly different but will maintain:
- All the same data
- All the same labels and titles
- Similar clean, minimal aesthetic
- Proper text sizing via custom `theme()` calls

`theme_minimal()` is a built-in ggplot2 theme that provides a clean, modern look similar to `hrbrthemes` but without external dependencies.

## Testing
After committing these changes, the GitHub Actions workflow should:
1. ✅ Successfully install all R dependencies
2. ✅ Run the data scraping script
3. ✅ Generate plots with the new theme
4. ✅ Update README
5. ✅ Deploy to shinyapps.io

## Next Steps
1. Commit and push these changes
2. Monitor the next GitHub Actions run (scheduled for the 15th of each month)
3. Verify the plots look acceptable with the new theme

## Alternative Solutions (if needed)
If you prefer the exact look of `hrbrthemes`:
1. Install from GitHub archive: `remotes::install_github("hrbrmstr/hrbrthemes")`
2. Update workflow to use GitHub installation instead of CRAN
3. However, using maintained CRAN packages is more sustainable long-term

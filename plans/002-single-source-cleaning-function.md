# Plan 002: Single-source the cleaning function and fix its two latent bugs

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 458d8cd..HEAD -- 02_scrape_auto.R scripts/fix_data.R scripts/rebuild_data.R data/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition. New commits that only add rows to
> `data/` files (a monthly INIDE update) are fine.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/001-data-validation-gate.md (safety net for the data regeneration in Step 6)
- **Category**: tech-debt + bug
- **Planned at**: commit `458d8cd`, 2026-06-12

## Why this matters

The 86-line `clean_canasta_data()` function is copy-pasted **three times**:
[02_scrape_auto.R:20–105](../02_scrape_auto.R), [scripts/fix_data.R:23–108](../scripts/fix_data.R),
[scripts/rebuild_data.R:38–123](../scripts/rebuild_data.R). The repo's own
[FIXES.md](../FIXES.md) shows this already caused a production incident: a fix
to the function had to be re-applied in multiple places, and the copies have
*also* drifted in how they write output (`readr::write_csv` vs base
`write.csv`, which produce differently-quoted CSVs). This plan extracts one
canonical copy and, while touching it, fixes two latent bugs:

1. **Fragile disambiguation**: duplicate goods ("Calcetines", "Pantalón…")
   are split into (Hombre)/(Niños y Niñas)/(Mujeres) variants by *positional*
   `row_number()` within each month. If INIDE ever reorders rows or drops one,
   items get silently mislabeled. The Excel files carry an official item
   number in the `row` column, and it is verified stable across all 220
   months (Calcetines Hombre = row 42, Niños = 52; Pantalón Hombre = 39,
   Mujeres = 45, in every single month). Keying on `row` removes the
   order-dependence entirely.
2. **Split unit for Fósforos**: `medida` appears as both
   `"cajita de 40 cerillos"` and `"cajita de 40 cerrillos"` (INIDE typo).
   This is the only good with two `medida` values, and it makes
   `unique(medida)` length-2 in the Shiny app's plot title (app.R:115–119).

## Current state

- `02_scrape_auto.R:20–105` — `clean_canasta_data()` definition (the pipeline
  copy). The other two copies are byte-for-byte identical in logic.
- The disambiguation block as it exists today (identical in all 3 copies;
  this is `02_scrape_auto.R:74–90`):

  ```r
      # Add row ID within each month for specific item disambiguation
      group_by(ym) %>%
      mutate(
        rowid = row_number()
      ) %>%
      ungroup() %>%

      # Disambiguate items that appear multiple times with different specifications
      mutate(
        good = case_when(
          good == "Calcetines" & rowid == 42 ~ "Calcetines (Hombre)",
          good == "Calcetines" & rowid == 52 ~ "Calcetines (Niños y Niñas)",
          good == "Pantalón largo de tela de jeans" & rowid == 39 ~ "Pantalón largo de tela de jeans (Hombre)",
          good == "Pantalón largo de tela de jeans" & rowid == 45 ~ "Pantalón largo de tela de jeans (Mujeres)",
          TRUE ~ good
        )
      ) %>%
  ```

  The trailing `select(-rowid)` at line 102 removes the helper column. The
  `rowid` exists *only* for this block, so switching the key to the official
  `row` column lets you delete the `group_by`/`rowid`/`ungroup` machinery.

- `02_scrape_auto.R:349–352` — where the pipeline calls the function:
  ```r
  cat("Applying data cleaning...\n")
  cat("Column names before cleaning:", paste(names(all_data), collapse = ", "), "\n")
  all_data_cleaned <- clean_canasta_data(all_data)
  ```

- `scripts/fix_data.R:131–139` and `scripts/rebuild_data.R:145–161` write
  output with `readr::write_csv()`, while the pipeline
  (`02_scrape_auto.R:359–385`) uses base `write.csv(..., row.names = FALSE)`.
  The committed `data/CB_FULL.csv` is in base-`write.csv` format (all
  character values quoted). The utility scripts must switch to the pipeline's
  writers or any manual repair rewrites the entire CSV's quoting.

- Data facts (verified at `458d8cd`):
  - `data/CB_FULL_raw.rds`: 11,660 rows; columns
    `yymm, year, month, url, row, bien, medida, cantidad, precio, total, id`;
    `row` is character; `month` is character.
  - `data/CB_FULL.rds`: same rows; `bien` renamed/merged to `good`; `month`
    is a factor; extra `ym` Date column.
  - Cleaning the committed raw with the *current* function reproduces the
    committed clean dataset exactly (the last pipeline run wrote both from
    the same in-memory object).
  - `row` may arrive numeric on some code paths (`read_csv` of monthly files
    parses it as double; `read_excel` sometimes yields numeric) — always
    compare via `as.character(row)`.

- Conventions: tidyverse pipes, `cat()` progress messages, scripts run from
  the repo root with `Rscript`. There is no `R/` directory yet — this plan
  creates it (standard R project layout for sourced functions).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| R syntax check | `Rscript -e 'invisible(parse("R/clean_canasta_data.R"))'` | no output, exit 0 |
| Characterization test | `Rscript tests/test_clean_canasta_data.R` | `PASS` line, exit 0 |
| Data validation | `Rscript scripts/validate_data.R` | `PASS:` line, exit 0 (exists once plan 001 landed) |
| Regenerate cleaned data | `Rscript scripts/fix_data.R` | ends with `Data successfully repaired!`, exit 0 |

(Local R is 4.5.2 with dplyr/forcats/stringr/lubridate/readr/haven installed —
verified during recon.)

## Scope

**In scope** (the only files you should modify/create):
- `R/clean_canasta_data.R` (create)
- `tests/test_clean_canasta_data.R` (create)
- `02_scrape_auto.R` (delete inline function, add `source()`)
- `scripts/fix_data.R` (delete inline function, add `source()`, align writers)
- `scripts/rebuild_data.R` (delete inline function, add `source()`, align writers)
- `data/CB_FULL.csv`, `data/CB_FULL.rds`, `data/CB_FULL.dta` (regenerated in Step 6)
- `scripts/README.md` (note that scripts must run from the repo root)

**Out of scope** (do NOT touch, even though they look related):
- `data/CB_FULL_raw.csv`, `data/CB_FULL_raw.rds` — the raw files are the
  append-anchor for the pipeline; this plan must not rewrite them.
- `data/monthly/` — source-of-truth snapshots; never regenerated.
- `01_files.R`, `02_scrape.R` — legacy one-shot historical scripts.
- `app.R` — handled by plan 004.
- The scraping/downloading functions in `02_scrape_auto.R`
  (`get_available_urls`, `get_data_safe`, main execution) — handled by plan 005.

## Git workflow

- Branch: `advisor/002-single-source-cleaning`
- Two commits suggested: (1) code refactor + test, (2) regenerated data files.
  Message style: short imperative, e.g. `Extract clean_canasta_data into R/`
  and `Regenerate cleaned data with standardized Fósforos medida`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Create `R/clean_canasta_data.R`

Create the directory and file. Content — this is the current function with
(a) the `group_by(ym)/rowid` block replaced by `row`-keyed disambiguation and
(b) one added `medida` standardization line. Everything else is verbatim from
`02_scrape_auto.R:20–105`:

```r
# Canonical cleaning function for the canasta basica pipeline.
# SINGLE SOURCE OF TRUTH - sourced by 02_scrape_auto.R, scripts/fix_data.R
# and scripts/rebuild_data.R. Edit here only.
# Requires: dplyr, forcats, stringr, lubridate (callers load them).

clean_canasta_data <- function(data) {
  cleaned_data <- data %>%
    # Handle column naming - ensure we have 'good' column
    {
      if("bien" %in% names(.) && !"good" %in% names(.)) {
        # Case 1: Only 'bien' exists, rename it to 'good'
        rename(., good = bien)
      } else if("bien" %in% names(.) && "good" %in% names(.)) {
        # Case 2: Both exist, merge them (coalesce to get non-NA values from either)
        mutate(., good = coalesce(good, bien)) %>%
        select(., -bien)
      } else {
        # Case 3: Only 'good' exists or neither exists
        .
      }
    } %>%

    # Set proper factor levels for months
    mutate(
      month = fct_relevel(
        month,
        "Ene", "Feb", "Mar", "Abr", "May", "Jun",
        "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"
      )
    ) %>%

    # Clean good names and standardize variations
    mutate(
      good = str_squish(good),
      good = case_when(
        str_detect(good, "Brassier") ~ "Brassier/sostén",
        str_detect(good, "Desodorante") ~ "Desodorante nacional",
        str_detect(good, "Pasta dental") ~ "Pasta dental",
        str_detect(good, "Pastas dental") ~ "Pasta dental",
        str_detect(good, "cuero natural") ~ "Zapato de cuero natural",
        # Consolidate duplicate goods to get to 53 unique items
        str_detect(good, "Detergente en polvo") ~ "Detergente",
        str_detect(good, "^Detergente$") ~ "Detergente",
        str_detect(good, "Jabón de lavar ropa") ~ "Jabón de lavar ropa",
        str_detect(good, "^Jabón de lavar$") ~ "Jabón de lavar ropa",
        str_detect(good, "Leche fluída") ~ "Leche",
        str_detect(good, "^Leche$") ~ "Leche",
        str_detect(good, "Chuleta de pescado") ~ "Chuleta de pescado",
        str_detect(good, "^Pescado$") ~ "Chuleta de pescado",
        TRUE ~ good
      )
    ) %>%

    # Create year-month variable for grouping
    mutate(
      ym = paste0(year, "-", as.numeric(month)),
      ym = ym(ym)
    ) %>%

    # Disambiguate items that appear multiple times, keyed on INIDE's
    # official item number (the `row` column) - stable in every month since
    # 2007, unlike positional row_number() which breaks if order changes
    mutate(
      good = case_when(
        good == "Calcetines" & as.character(row) == "42" ~ "Calcetines (Hombre)",
        good == "Calcetines" & as.character(row) == "52" ~ "Calcetines (Niños y Niñas)",
        good == "Pantalón largo de tela de jeans" & as.character(row) == "39" ~ "Pantalón largo de tela de jeans (Hombre)",
        good == "Pantalón largo de tela de jeans" & as.character(row) == "45" ~ "Pantalón largo de tela de jeans (Mujeres)",
        TRUE ~ good
      )
    ) %>%

    # Clean medida and handle special cases for precio
    mutate(
      medida = str_to_lower(medida),
      # INIDE spells Fósforos' unit both "cerillos" and "cerrillos";
      # standardize so every good has exactly one medida
      medida = str_replace(medida, "cerrillos", "cerillos"),
      precio = case_when(
        is.na(precio) & good == "Alquiler" ~ total,
        TRUE ~ precio
      )
    )

  cleaned_data
}
```

Note what is *gone* relative to the old copies: `group_by(ym)`,
`mutate(rowid = row_number())`, `ungroup()`, and the final `select(-rowid)`.
The output columns are unchanged.

**Verify**: `Rscript -e 'invisible(parse("R/clean_canasta_data.R"))'` → exit 0.

### Step 2: Create the characterization test `tests/test_clean_canasta_data.R`

```r
# Characterization test: the shared cleaning function must reproduce the
# committed cleaned dataset from the committed raw dataset.
# Only permitted difference: medida "cajita de 40 cerrillos" ->
# "cajita de 40 cerillos" (Fósforos standardization added in plan 002).
# Run from the repo root: Rscript tests/test_clean_canasta_data.R

suppressPackageStartupMessages({
  library(dplyr); library(forcats); library(stringr); library(lubridate)
})
source("R/clean_canasta_data.R")

raw      <- readRDS("data/CB_FULL_raw.rds")
expected <- readRDS("data/CB_FULL.rds")
actual   <- clean_canasta_data(raw)

stopifnot(nrow(actual) == nrow(expected))
stopifnot(identical(names(actual), names(expected)))

for (col in setdiff(names(expected), "medida")) {
  a <- actual[[col]]; e <- expected[[col]]
  same <- if (is.numeric(a) && is.numeric(e)) {
    isTRUE(all.equal(a, e))
  } else {
    identical(as.character(a), as.character(e))
  }
  if (!same) stop("column differs unexpectedly: ", col)
}

diff_idx <- which(actual$medida != expected$medida)
if (length(diff_idx) > 0) {
  stopifnot(all(expected$medida[diff_idx] == "cajita de 40 cerrillos"))
  stopifnot(all(actual$medida[diff_idx] == "cajita de 40 cerillos"))
}

cat(sprintf("PASS: cleaning reproduces committed dataset (%d medida values standardized)\n",
            length(diff_idx)))
```

**Verify**: `Rscript tests/test_clean_canasta_data.R` →
`PASS: cleaning reproduces committed dataset (99 medida values standardized)`,
exit 0 — the "cerrillos" typo appears in 99 of the 220 months (verified at
`458d8cd` by running this exact test). (After Step 6 regenerates the data,
the count drops to 0 — both are passes.) **If any column "differs unexpectedly", that is a STOP condition** —
it means the row-keyed disambiguation is NOT equivalent to the positional one
on real data, and the refactor must not proceed on assumption.

### Step 3: Replace the inline copy in `02_scrape_auto.R`

1. Delete lines 18–105 (from the comment
   `# Data cleaning function ------------------------------------------------`
   through the end of the function definition, `}` followed by the blank line
   before `# Function to scrape available URLs from the website`).
2. In their place put:

```r
# Data cleaning function (single source of truth) -------------------------

source("R/clean_canasta_data.R")
```

The script already assumes the repo root as working directory (it reads
`data/CB_FULL.rds` by relative path), so a relative `source()` is consistent.

**Verify**: `Rscript -e 'invisible(parse("02_scrape_auto.R"))'` → exit 0, and
`grep -c "clean_canasta_data <- function" 02_scrape_auto.R` → `0`, and
`grep -c 'source("R/clean_canasta_data.R")' 02_scrape_auto.R` → `1`.

### Step 4: Same replacement in `scripts/fix_data.R` and `scripts/rebuild_data.R`

For each file, delete the inline `clean_canasta_data` definition
(`fix_data.R:22–108`, from the comment `# Define the cleaning function inline (with the fix)`
through the closing `}`; `rebuild_data.R:37–123` likewise) and replace with:

```r
# Cleaning function comes from the single shared source.
# NOTE: run this script from the repo root, e.g. Rscript scripts/fix_data.R
source("R/clean_canasta_data.R")
```

**Verify**: `grep -rc "clean_canasta_data <- function" 02_scrape_auto.R scripts/fix_data.R scripts/rebuild_data.R` → `0` for all three files, and
`grep -l 'source("R/clean_canasta_data.R")' scripts/fix_data.R scripts/rebuild_data.R` → both listed, and both files parse
(`Rscript -e 'invisible(parse("scripts/fix_data.R")); invisible(parse("scripts/rebuild_data.R"))'` → exit 0).

### Step 5: Align the utility scripts' writers with the pipeline

The pipeline writes CSVs with base `write.csv(..., row.names = FALSE)`
(`02_scrape_auto.R:359–375`); the utility scripts use `readr::write_csv()`,
which quotes differently and would rewrite the whole committed CSV on any
manual repair. In `scripts/fix_data.R` (lines ~131–139 pre-edit) and
`scripts/rebuild_data.R` (lines ~145–161 pre-edit), replace every
`write_csv(x, "path")` call with `write.csv(x, "path", row.names = FALSE)`
keeping the same paths. Pipe form is fine, e.g.:

```r
cleaned_data %>%
  write.csv("data/CB_FULL.csv", row.names = FALSE)
```

Leave the `write_rds()` / `write_dta()` calls as they are (they match the
pipeline already).

**Verify**: `grep -n "write_csv" scripts/fix_data.R scripts/rebuild_data.R` → no matches; both files still parse.

### Step 6: Regenerate the cleaned data files

The medida standardization only materializes in the committed data when the
cleaning re-runs, and the pipeline skips cleaning when INIDE has no new month.
Run the repair script once:

```bash
Rscript scripts/fix_data.R
```

**Verify** (all three):
1. `Rscript tests/test_clean_canasta_data.R` →
   `PASS ... (0 medida values standardized)`.
2. `Rscript scripts/validate_data.R` → `PASS:` line, exit 0 (requires plan 001;
   if it has not landed, skip this check and note it in your report).
3. The diff touches only Fósforos medida values — run:

```bash
python3 - <<'EOF'
import csv, io, subprocess
old = list(csv.DictReader(io.StringIO(subprocess.run(
    ['git','show','HEAD:data/CB_FULL.csv'],capture_output=True,text=True).stdout)))
new = list(csv.DictReader(open('data/CB_FULL.csv')))
assert len(old) == len(new), f'row count changed: {len(old)} -> {len(new)}'
diffs = [(o,n) for o,n in zip(old,new) if o != n]
assert diffs, 'expected Fósforos medida changes, found none'
for o,n in diffs:
    changed = {k for k in o if o[k] != n[k]}
    assert o['good'] == 'Fósforos' and changed == {'medida'}, f'unexpected diff: {o["yymm"]} {o["good"]} {changed}'
print(f'OK: {len(diffs)} rows changed, all Fósforos medida only')
EOF
```
→ `OK: 99 rows changed, all Fósforos medida only` (count may differ slightly
if new months landed since `458d8cd`).
4. `git status --porcelain data/` shows **only**
   `data/CB_FULL.csv`, `data/CB_FULL.rds`, `data/CB_FULL.dta` modified —
   the `*_raw.*` files and `data/monthly/` must be untouched.

### Step 7: Update `scripts/README.md`

Add one line to the top of `scripts/README.md` (after the intro sentence):

```markdown
All scripts must be run from the repository root (they use relative paths and
`source("R/clean_canasta_data.R")`).
```

**Verify**: `grep -n "repository root" scripts/README.md` → one match.

## Test plan

- `tests/test_clean_canasta_data.R` (Step 2) is the characterization test:
  it pins the refactored function to the committed data, covering the
  rename/coalesce branches, the name standardizations, the row-keyed
  disambiguation, and the medida fix in one shot. There is no existing test
  to model after — this is the repo's first test file.
- Step 6's python diff check proves the data regeneration changed exactly
  what was intended.
- Verification: `Rscript tests/test_clean_canasta_data.R` → PASS.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -rc "clean_canasta_data <- function" 02_scrape_auto.R scripts/fix_data.R scripts/rebuild_data.R` reports 0 for each; the only definition is in `R/clean_canasta_data.R`
- [ ] `grep -rn "rowid" R/ 02_scrape_auto.R scripts/` returns no matches
- [ ] `Rscript tests/test_clean_canasta_data.R` exits 0
- [ ] `Rscript scripts/validate_data.R` exits 0 (if plan 001 landed)
- [ ] Step 6's python diff check prints `OK: ... all Fósforos medida only`
- [ ] `git status --porcelain` shows changes only to in-scope files
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The Step 2 test reports any column "differs unexpectedly" — the row-keyed
  disambiguation is not equivalent to positional rowid on the real data.
- Step 6's diff check finds changes outside Fósforos `medida`.
- `data/CB_FULL_raw.*` or anything under `data/monthly/` shows as modified.
- Required R packages are missing and `install.packages()` of the missing
  package fails.
- The inline function copies do not match each other or the excerpt (drift).

## Maintenance notes

- All future cleaning-rule changes go in `R/clean_canasta_data.R` only; after
  changing a rule, run `scripts/fix_data.R` (re-clean from raw) or
  `scripts/rebuild_data.R` (rebuild from monthly CSVs) and then
  `scripts/validate_data.R`.
- The characterization test pins current behavior. When a cleaning rule is
  *intentionally* changed, the test's "permitted difference" block must be
  updated in the same commit — a reviewer should treat test edits without
  matching rule changes as a red flag.
- Plan 005 edits other parts of `02_scrape_auto.R`; land this plan first
  (005's drift check accounts for the line-number shift this plan causes).
- Deferred: `scripts/fix_data.R` still prints a hardcoded "2025 recent months"
  diagnostic block — harmless, not worth the churn now.

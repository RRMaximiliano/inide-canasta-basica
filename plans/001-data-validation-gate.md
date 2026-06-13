# Plan 001: Add an automated data-validation gate to the pipeline

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 458d8cd..HEAD -- scripts/ .github/workflows/update-data.yml data/CB_FULL.rds`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `458d8cd`, 2026-06-12

## Why this matters

This repo is an automated monthly data pipeline (GitHub Actions scrapes INIDE
Excel files, cleans them, and commits `data/CB_FULL.*`). It has **no automated
check of what it commits**. The repo's own history proves the cost:
[FIXES.md](../FIXES.md) documents that July–October 2025 data shipped with
`NA` values in the `good` column for **four months** before anyone noticed,
because nothing validated the output. A diagnostic script exists
([scripts/check_data.R](../scripts/check_data.R)) but it only prints, never
fails, hardcodes `year == 2025` / `month == "Oct"`, and is not run in CI.
This plan adds a validation script with hard assertions and wires it into the
workflow so a bad scrape fails the job *before* anything is committed or
deployed.

## Current state

- `.github/workflows/update-data.yml` — the monthly pipeline. Step order today:
  scrape (line 55–57) → check flag (59–68) → plots (70–73) → knit README
  (75–78) → cleanup (80–83) → commit data/figures/README (85–104) → deploy
  (106–176). **There is no validation step anywhere.**

  Excerpt (`update-data.yml:55–68`):
  ```yaml
        - name: Run data update script
          run: |
            Rscript 02_scrape_auto.R

        - name: Check if data changed
          id: check-data-changes
          run: |
            if [ -f "no_data_changes.flag" ]; then
              echo "data_changed=false" >> $GITHUB_OUTPUT
  ```

- `scripts/check_data.R` — print-only diagnostic, hardcoded to 2025/Oct
  (`check_data.R:9–23`), never exits non-zero. It stays as-is (out of scope);
  the new script supersedes it for CI purposes.

- `data/CB_FULL.rds` — the cleaned dataset. Columns:
  `yymm` (glue), `year` (numeric), `month` (factor, Spanish levels
  Ene…Dic), `url` (chr), `row` (chr), `good` (chr), `medida` (chr),
  `cantidad` (num), `precio` (num), `total` (num), `id` (num), `ym` (Date).

- **Invariants verified to hold on the current data** (at commit `458d8cd`,
  11,660 rows, Sep 2007 – Dec 2025). These are safe to assert:
  - exactly 53 rows per (year, month);
  - 220 contiguous months — no gaps;
  - exactly 53 unique `good` values;
  - zero NA in `year, month, good, medida, cantidad, precio, total, ym`;
  - no duplicate (year, month, row);
  - `cantidad`, `precio`, `total` all strictly positive;
  - `total == cantidad * precio` (exact today; assert with 1% relative
    tolerance to survive INIDE rounding in future files);
  - `ym` equals the first day of the (year, month).

- Repo conventions: plain R scripts at top level / in `scripts/`, run from the
  repo root via `Rscript`, heavy use of `cat()` progress messages. The
  validation script should use **base R only** (no dplyr/readr) so it runs in
  any environment with zero package installs — `readRDS()` covers reading.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Run validation | `Rscript scripts/validate_data.R` | line starting `PASS:`, exit 0 |
| R syntax check | `Rscript -e 'invisible(parse("scripts/validate_data.R"))'` | no output, exit 0 |
| YAML check | `Rscript -e 'invisible(yaml::read_yaml(".github/workflows/update-data.yml")); cat("yaml ok\n")'` | `yaml ok`, exit 0 |

(Verified during recon: local `Rscript` is R 4.5.2 and the `yaml` package is
installed. CI uses R 4.3.2 — base-R-only code runs on both.)

## Scope

**In scope** (the only files you should modify/create):
- `scripts/validate_data.R` (create)
- `.github/workflows/update-data.yml` (add one step)
- `scripts/README.md` (document the new script)

**Out of scope** (do NOT touch, even though they look related):
- `scripts/check_data.R`, `scripts/fix_data.R`, `scripts/rebuild_data.R` —
  handled by plan 002; touching them here creates merge conflicts.
- `02_scrape_auto.R` — handled by plans 002 and 005.
- Anything under `data/` — this plan only reads data, never writes it.

## Git workflow

- Branch: `advisor/001-data-validation-gate`
- Single commit is fine; message style in this repo is short imperative
  (e.g. `Update data through Dec 2025, fix date detection, remove emojis`).
  Suggested: `Add data validation script and CI gate`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Create `scripts/validate_data.R`

Create the file with exactly this content (base R only, accepts an optional
path argument so it can be tested against corrupted copies):

```r
#!/usr/bin/env Rscript
# Validates the cleaned canasta basica dataset. Run from the repo root:
#   Rscript scripts/validate_data.R [path-to-rds]
# Defaults to data/CB_FULL.rds. Prints PASS and exits 0 when all checks
# hold; prints every failure and exits 1 otherwise. Base R only so it runs
# in CI without package installs.

args <- commandArgs(trailingOnly = TRUE)
path <- if (length(args) >= 1) args[1] else "data/CB_FULL.rds"

MONTH_LEVELS <- c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
                  "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")
EXPECTED_GOODS <- 53           # update if INIDE ever revises the basket
EXPECTED_ROWS_PER_MONTH <- 53

failures <- character(0)
fail <- function(msg) failures <<- c(failures, msg)

if (!file.exists(path)) {
  cat("DATA VALIDATION FAILED:", path, "does not exist\n")
  quit(status = 1)
}

d <- readRDS(path)
d$month <- as.character(d$month)
d$row   <- as.character(d$row)

# 1. Required columns
required <- c("yymm", "year", "month", "url", "row", "good", "medida",
              "cantidad", "precio", "total", "ym")
missing <- setdiff(required, names(d))
if (length(missing) > 0) {
  cat("DATA VALIDATION FAILED: missing columns:",
      paste(missing, collapse = ", "), "\n")
  quit(status = 1)
}

# 2. Valid month labels
bad_months <- setdiff(unique(d$month), MONTH_LEVELS)
if (length(bad_months) > 0)
  fail(paste("invalid month labels:", paste(bad_months, collapse = ", ")))

# 3. No NAs in key columns
for (col in c("year", "month", "good", "medida", "cantidad",
              "precio", "total", "ym")) {
  n_na <- sum(is.na(d[[col]]))
  if (n_na > 0) fail(sprintf("%d NA values in column '%s'", n_na, col))
}

# 4. Exactly EXPECTED_ROWS_PER_MONTH rows per (year, month)
ym_key <- paste(d$year, d$month)
counts <- table(ym_key)
bad <- counts[counts != EXPECTED_ROWS_PER_MONTH]
if (length(bad) > 0)
  fail(paste0("months with row count != ", EXPECTED_ROWS_PER_MONTH, ": ",
              paste(names(bad), "=", bad, collapse = "; ")))

# 5. Exactly EXPECTED_GOODS unique goods
n_goods <- length(unique(d$good))
if (n_goods != EXPECTED_GOODS)
  fail(sprintf("expected %d unique goods, found %d", EXPECTED_GOODS, n_goods))

# 6. No duplicated (year, month, row)
dup <- duplicated(paste(d$year, d$month, d$row))
if (any(dup))
  fail(sprintf("%d duplicated (year, month, row) entries", sum(dup)))

# 7. Contiguous monthly series, no gaps
mnum <- match(d$month, MONTH_LEVELS)
idx <- sort(unique(d$year * 12 + (mnum - 1)))
n_gaps <- sum(diff(idx) != 1)
if (n_gaps > 0) fail(sprintf("%d gap(s) in the monthly series", n_gaps))

# 8. Strictly positive values
for (col in c("cantidad", "precio", "total")) {
  n_bad <- sum(d[[col]] <= 0, na.rm = TRUE)
  if (n_bad > 0) fail(sprintf("%d non-positive values in '%s'", n_bad, col))
}

# 9. total ~= cantidad * precio (1% relative tolerance)
rel_err <- abs(d$cantidad * d$precio - d$total) / pmax(abs(d$total), 1e-9)
n_bad <- sum(rel_err > 0.01, na.rm = TRUE)
if (n_bad > 0)
  fail(sprintf("%d rows where total deviates >1%% from cantidad*precio", n_bad))

# 10. ym consistent with year/month
ym_expected <- as.Date(sprintf("%d-%02d-01", d$year, mnum))
n_bad <- sum(d$ym != ym_expected, na.rm = TRUE)
if (n_bad > 0)
  fail(sprintf("%d rows where 'ym' does not match year/month", n_bad))

# Report -------------------------------------------------------------------
if (length(failures) > 0) {
  cat("DATA VALIDATION FAILED for", path, "\n")
  cat(paste(" -", failures), sep = "\n")
  quit(status = 1)
}

fmt <- function(i) sprintf("%s %d", MONTH_LEVELS[i %% 12 + 1], i %/% 12)
cat(sprintf("PASS: %d rows | %d months | %s -> %s | %d unique goods\n",
            nrow(d), length(counts), fmt(min(idx)), fmt(max(idx)), n_goods))
```

**Verify**: `Rscript scripts/validate_data.R` →
`PASS: 11660 rows | 220 months | Sep 2007 -> Dic 2025 | 53 unique goods`, exit 0.
(Row/month numbers will be higher if new INIDE months landed since `458d8cd` —
that is fine; what matters is `PASS` and exit 0.)

### Step 2: Negative test — the script must FAIL on corrupted data

Run this one-liner. It copies the dataset, injects an NA into `good`, runs the
validator against the copy, and exits 0 only if the validator exited 1:

```bash
Rscript -e 'd <- readRDS("data/CB_FULL.rds"); d$good[1] <- NA; p <- tempfile(fileext = ".rds"); saveRDS(d, p); s <- system2("Rscript", c("scripts/validate_data.R", p)); quit(status = as.integer(s != 1))'
```

**Verify**: command prints a `DATA VALIDATION FAILED` block mentioning
`1 NA values in column 'good'` and the overall command exits 0.

### Step 3: Wire the gate into the workflow

In `.github/workflows/update-data.yml`, insert a new step **between**
`Run data update script` and `Check if data changed` (i.e. after current line
57). Match the existing two-space indentation:

```yaml
      - name: Validate data
        run: |
          Rscript scripts/validate_data.R
```

It deliberately runs even when no new data was scraped — it then re-validates
the committed dataset, which is cheap and catches corruption introduced by
manual repairs. Because it runs before the commit and deploy steps, a failed
validation aborts the job and nothing bad is committed or deployed.

**Verify**:
`Rscript -e 'invisible(yaml::read_yaml(".github/workflows/update-data.yml")); cat("yaml ok\n")'` → `yaml ok`, exit 0.
`grep -n "validate_data" .github/workflows/update-data.yml` → one match inside the new step.

### Step 4: Document the script in `scripts/README.md`

Add a section alongside the existing ones (match their format — heading,
"When to use", "Usage"):

```markdown
### `validate_data.R`
Hard validation of the cleaned dataset. Exits non-zero on any failure.
Runs automatically in CI after every scrape; can be run manually anytime.

**When to use:**
- Runs automatically in GitHub Actions on every pipeline run
- After any manual data repair (`fix_data.R`, `rebuild_data.R`)

**Usage:**
```r
Rscript scripts/validate_data.R
```
```

Also update the closing "Note" section of `scripts/README.md`: it currently
says these scripts are *not* part of the automated workflow; amend it to state
that `validate_data.R` is the exception (it runs in CI).

**Verify**: `grep -n "validate_data" scripts/README.md` → at least 2 matches.

## Test plan

This plan's deliverable *is* test infrastructure. Coverage:
- Positive: Step 1's verify (real data passes).
- Negative: Step 2's verify (corrupted data fails with the right message).
No separate test files are needed; there is no test framework in this repo.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `Rscript scripts/validate_data.R` exits 0 and prints a `PASS:` line
- [ ] The Step 2 negative-test one-liner exits 0
- [ ] `Rscript -e 'invisible(yaml::read_yaml(".github/workflows/update-data.yml"))'` exits 0
- [ ] `grep -c "Validate data" .github/workflows/update-data.yml` → `1`
- [ ] `git status --porcelain` shows changes only to the three in-scope files
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- `Rscript scripts/validate_data.R` fails on the *current* committed data —
  that means real data corruption exists right now; report which check fired
  instead of loosening the check.
- The workflow file's step names/order don't match the excerpt in "Current
  state" (drift — plan 005 may have landed first).
- `data/CB_FULL.rds` lacks any of the columns listed in "Current state".

## Maintenance notes

- If INIDE revises the basket (item count ≠ 53), update `EXPECTED_GOODS` and
  `EXPECTED_ROWS_PER_MONTH` — the failure message will say exactly that.
- Plan 002 changes the cleaning function; this gate is the safety net for
  that change. Land this plan first.
- Reviewer should scrutinize: that the workflow step is *before* the commit
  step, and that the script exits non-zero (not just prints) on failure.
- Deferred: validating the raw dataset (`CB_FULL_raw.rds`) and the per-month
  CSVs — lower value, the cleaned RDS is what the app and users consume.

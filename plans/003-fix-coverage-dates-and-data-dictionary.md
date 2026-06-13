# Plan 003: Fix the misreported coverage start date and complete the README data dictionary

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 458d8cd..HEAD -- README.Rmd 03_plots.R README.md figures/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug + docs
- **Planned at**: commit `458d8cd`, 2026-06-12

## Why this matters

The dataset covers **September 2007** through the latest month, but the
public README and all three README figures say coverage starts **"Dic 2007"**.
Cause: the "first month" is computed as *the first 2007 row in file order*,
and the 2007 rows are stored in reverse order (Dic, Nov, Oct, Sep — verified
in `data/CB_FULL.csv`). For a dataset whose whole point is public reference
data, the headline coverage claim being wrong erodes trust. Separately, the
README's variable list documents 10 columns but the dataset ships 12 — `id`
(an internal download-batch artifact users will otherwise puzzle over) and
`ym` are undocumented.

## Current state

- `README.Rmd:20–28` — the buggy min vs. the correct max idiom side by side:

  ```r
  min_year <- min(canasta_basica$year)
  max_year <- max(canasta_basica$year)
  min_month <- canasta_basica$month[canasta_basica$year == min_year][1]
  max_month_data <- canasta_basica %>%
    filter(year == max_year) %>%
    arrange(desc(match(month, c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
                                "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")))) %>%
    slice(1)
  max_month <- max_month_data$month
  ```

  `[1]` takes the first row in storage order — "Dic" — not the earliest month.

- `03_plots.R:18–26` — the same buggy pattern feeding every figure subtitle:

  ```r
  min_year <- min(df$year)
  max_year <- max(df$year)
  min_month <- df$month[df$year == min_year][1]
  ```

- `README.md:20–21` (generated) — the visible symptom:
  `**Cobertura**: Dic 2007 - Dic 2025`.

- `README.Rmd:88–99` — the variable list. It documents `yymm, year, month,
  url, row, good, medida, cantidad, precio, total` and omits `id` and `ym`.
  Facts about the missing two (verified in data): `id` is a numeric artifact
  of the historical download process (the URL batch index — e.g. 4 for all
  Dec 2007 rows, 194 for Oct 2023; not an item identifier); `ym` is a `Date`,
  always the first day of the (year, month).

- `README.md` is generated — the header comment says
  `<!-- README.md is generated from README.Rmd. Please edit that file -->`.
  The CI workflow regenerates it with
  `Rscript -e "knitr::knit('README.Rmd', output = 'README.md')"`
  (`.github/workflows/update-data.yml:75–78`), and regenerates figures with
  `Rscript 03_plots.R`. Note: `README.Rmd` sets `last_update <- Sys.Date()`,
  so re-knitting also bumps the "actualizado" date — expected behavior of the
  generated file, not a problem.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| R syntax check | `Rscript -e 'invisible(parse("03_plots.R"))'` | no output, exit 0 |
| Re-knit README | `Rscript -e "knitr::knit('README.Rmd', output = 'README.md')"` | README.md rewritten, exit 0 |
| Regenerate figures | `Rscript 03_plots.R` | three `... plot saved` lines, exit 0 |
| Check the fix | `grep -n "Cobertura" README.md` | line containing `Sep 2007` |

(Verified during recon: local R 4.5.2 has dplyr, readr, lubridate, knitr,
ggplot2, glue, scales installed.)

## Scope

**In scope** (the only files you should modify):
- `README.Rmd`
- `03_plots.R`
- `README.md` (regenerated, never hand-edited)
- `figures/arroz.png`, `figures/queso_seco.png`, `figures/canasta_basica.png` (regenerated)

**Out of scope** (do NOT touch, even though they look related):
- `app.R` — its "last update" sidebar uses the max-month idiom, which is
  correct; app changes belong to plan 004.
- `02_scrape_auto.R`, `scripts/` — plans 002/005.
- `README_files/` — stale Quarto artifacts, unrelated.

## Git workflow

- Branch: `advisor/003-coverage-dates`
- One commit; suggested message: `Fix coverage start month and document id/ym columns`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Fix `min_month` in `README.Rmd`

Replace line 22 (`min_month <- canasta_basica$month[canasta_basica$year == min_year][1]`)
with the same idiom the file already uses for the max (ascending instead of
descending):

```r
min_month_data <- canasta_basica %>%
  filter(year == min_year) %>%
  arrange(match(month, c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
                         "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"))) %>%
  slice(1)
min_month <- min_month_data$month
```

**Verify**: `grep -n "min_month" README.Rmd` shows the new block and no
`[1]`-indexing form remains.

### Step 2: Same fix in `03_plots.R`

Replace line 20 (`min_month <- df$month[df$year == min_year][1]`) with:

```r
min_month_data <- df %>%
  filter(year == min_year) %>%
  arrange(match(month, c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
                         "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"))) %>%
  slice(1)
min_month <- min_month_data$month
```

**Verify**: `Rscript -e 'invisible(parse("03_plots.R"))'` → exit 0.

### Step 3: Document `id` and `ym` in the README variable list

In `README.Rmd`, the variable list (lines 88–99) ends with:

```markdown
* `precio`: Precio por medida.
* `total`: Total de consumo.
```

Append two bullets after `total`:

```markdown
* `id`: Identificador interno del lote de descarga (artefacto del proceso de recolección; no identifica al bien).
* `ym`: Fecha del primer día del mes correspondiente (construida a partir de `year` y `month`).
```

**Verify**: `grep -n '`ym`' README.Rmd` → match in the variable list.

### Step 4: Regenerate README.md and the figures

```bash
Rscript -e "knitr::knit('README.Rmd', output = 'README.md')"
Rscript 03_plots.R
```

**Verify**:
- `grep -n "Cobertura" README.md` → contains `Sep 2007 - <latest month/year>`
  (latest was `Dic 2025` at planning time; newer is fine).
- `grep -c '`id`' README.md` → at least 1.
- `Rscript 03_plots.R` printed all three `plot saved` messages;
  `git status --porcelain figures/` shows the three PNGs modified.
- The figure subtitles now read `Sep 2007 - ...` (PNG content can't be
  grepped; rely on the corrected `date_range` value — optionally print it:
  `Rscript -e 'source("03_plots.R")' 2>&1 | grep "date range"` →
  `Generating plots with date range: Sep 2007 - ...`).

## Test plan

No test framework exists in this repo (plan 001 adds data validation, which
doesn't cover docs). Verification is the grep gates above. If plan 001 has
landed, also run `Rscript scripts/validate_data.R` → `PASS` (proves the knit
didn't touch data).

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -n "Cobertura" README.md` contains `Sep 2007`
- [ ] `grep -rn 'month\[' README.Rmd 03_plots.R` returns no matches (the `[1]` pattern is gone from both)
- [ ] README.md variable list includes `id` and `ym`
- [ ] `git status --porcelain` shows only the in-scope files modified
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- `knitr::knit` fails (likely a missing package — report which).
- After the fix, the computed coverage start is anything other than
  `Sep 2007` — the data itself would then differ from what this plan was
  written against.
- README.md regeneration produces unexpected wholesale changes beyond the
  coverage line, the new bullets, the `actualizado` dates, and the routine
  tibble-preview noise.

## Maintenance notes

- README.md and `figures/*.png` are build artifacts; CI regenerates them
  monthly. The durable fix is in README.Rmd and 03_plots.R — reviewers should
  focus there.
- If the min/max month logic is ever needed a third time, extract a shared
  helper (alongside `R/clean_canasta_data.R` from plan 002); at two call
  sites it is not yet worth it.

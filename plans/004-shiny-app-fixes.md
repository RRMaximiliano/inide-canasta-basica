# Plan 004: Fix the Shiny app's broken export buttons, unsafe download filename, and fragile aggregations

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 458d8cd..HEAD -- app.R`
> If app.R changed since this plan was written, compare the "Current state"
> excerpts against the live code before proceeding; on a mismatch, treat it
> as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `458d8cd`, 2026-06-12

## Why this matters

The deployed app (https://rrmaximiliano.shinyapps.io/inide-canasta-basica/)
has four small but real defects, all in [app.R](../app.R):

1. Both data tables request DT's Buttons toolbar (`dom = 'Bfrtip'` with a
   `buttons` list) but never pass `extensions = 'Buttons'` — so the
   copy/csv/excel/pdf/print buttons **never render**. Dead config shipped to
   production.
2. The CSV download filename is built from the raw good name. The dataset
   contains `"Brassier/sostén"` — a `/` in a download filename, which
   browsers mangle or reject.
3. The grouped-total aggregation uses `sum(total)` without `na.rm = TRUE`,
   unlike its twin in `03_plots.R:129` which uses `na.rm = TRUE`. The data
   has no NA today, but one bad future month would blank the entire series
   tab (this exact class of corruption happened in 2025 — see FIXES.md).
4. The per-good plot title uses `unique(filtered_data()$medida)`, which is
   length-2 for Fósforos (split unit spelling in the data) — a vectorized
   value where a scalar is expected. Plan 002 fixes the data; the app should
   still be defensive.

Plus a trivial cleanup: `library(readr)` is loaded twice (lines 4 and 12).

## Current state

All excerpts from `app.R` at `458d8cd`:

- Duplicate library (lines 2–12): `library(readr)` appears at line 4 and
  again at line 12.

- Grouped aggregation (lines 38–43):
  ```r
  grouped_data <- data %>%
    group_by(year, month) %>%
    summarize(
      sum = sum(total),
      .groups = "drop"
    )
  ```

- Plot title (lines 114–119):
  ```r
  output$plotBien <- renderPlot({
    title_lab <- sprintf(
      "Precio nominal de %s de %s",
      unique(filtered_data()$medida),
      input$good
    )
  ```

- Table 1 without the Buttons extension (lines 160–174):
  ```r
  output$tableBien <- renderDataTable({
    filtered_data() %>%
      arrange(desc(ym)) %>%
      select(year, month, good, medida, cantidad, precio, total) %>%
      # arrange(year, month) %>%
      DT::datatable(
        options = list(
          dom = 'Bfrtip',
          buttons = c('copy', 'csv', 'excel', 'pdf', 'print')
        ),
        rownames = FALSE,
        class = "table-striped"
      ) %>%
      formatRound(columns=c("precio", "total"), digits = 3)
  })
  ```

- Download handler (lines 177–184):
  ```r
  output$download1 <- downloadHandler(
    filename = function() {
      paste0("inide_canasta_basica_", input$good, "_", Sys.Date(), ".csv")
    },
    content = function(file) {
      write.csv(filtered_data(), file)
    }
  )
  ```

- Table 2, same missing extension (lines 221–239), ending in
  `formatRound(columns = c("total"), digits = 1)`.

- The UI uses `dataTableOutput` (lines 88, 93) and the server uses
  `renderDataTable` (lines 160, 221). These currently resolve to DT's
  versions only because `library(DT)` (line 11) is loaded after
  `library(shiny)` (line 2) and masks shiny's — a load-order accident worth
  making explicit.

- Deployment note: `.rscignore` ships only `app.R` + `data/CB_FULL.rds` to
  shinyapps.io; nothing else in the repo affects the app.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| R syntax check | `Rscript -e 'invisible(parse("app.R"))'` | no output, exit 0 |
| Smoke test (builds the app object, loads data, runs all top-level code) | `Rscript -e 'app <- source("app.R")$value; stopifnot(inherits(app, "shiny.appobj")); cat("app ok\n")'` | `app ok`, exit 0 |
| Manual run (optional, interactive) | `Rscript -e 'shiny::runApp(".", port = 4242)'` then open http://localhost:4242 | buttons visible above tables |

(Verified during recon: local R 4.5.2 has shiny, DT, bslib, dplyr, readr,
ggplot2, lubridate, forcats, stringr, scales installed.)

## Scope

**In scope** (the only file you should modify):
- `app.R`

**Out of scope** (do NOT touch, even though they look related):
- `data/*` — the Fósforos medida fix in the data belongs to plan 002.
- `03_plots.R`, `README.Rmd` — plan 003.
- `.rscignore`, deployment workflow — plan 005.
- Visual design, themes, layout — no restyling.

## Git workflow

- Branch: `advisor/004-shiny-app-fixes`
- One commit; suggested message: `Fix DT export buttons, download filename, and NA handling in app`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Remove the duplicate `library(readr)`

Delete line 12 (`library(readr)` — the second occurrence, the one after
`library(DT)`).

**Verify**: `grep -c "library(readr)" app.R` → `1`.

### Step 2: Make the aggregation NA-safe

In the `grouped_data` block (lines 38–43 pre-edit), change
`sum = sum(total)` to `sum = sum(total, na.rm = TRUE)` — matching
`03_plots.R:129`.

**Verify**: `grep -n "na.rm = TRUE" app.R` → one match in the
`grouped_data` block.

### Step 3: Scalar-safe plot title

In `output$plotBien` (lines 114–119 pre-edit), change

```r
      unique(filtered_data()$medida),
```
to
```r
      unique(filtered_data()$medida)[1],
```

**Verify**: `grep -n 'unique(filtered_data()\$medida)\[1\]' app.R` → one match.

### Step 4: Enable the Buttons extension on both tables

In **both** `DT::datatable(` calls (in `output$tableBien` and
`output$tableCanasta`), add `extensions = 'Buttons',` as the first argument
after the data, e.g.:

```r
      DT::datatable(
        extensions = 'Buttons',
        options = list(
          dom = 'Bfrtip',
          buttons = c('copy', 'csv', 'excel', 'pdf', 'print')
        ),
        rownames = FALSE,
        class = "table-striped"
      )
```

Also make the output/render pairing explicit (removes the load-order
dependence): replace both `dataTableOutput(` calls in the UI with
`DT::DTOutput(` and both `renderDataTable({` calls in the server with
`DT::renderDT({`.

**Verify**:
`grep -c "extensions = 'Buttons'" app.R` → `2`;
`grep -c "DT::DTOutput" app.R` → `2`;
`grep -c "DT::renderDT" app.R` → `2`;
`grep -c "renderDataTable\|dataTableOutput" app.R` → `0`.

### Step 5: Sanitize the download filename and drop row names

Replace the `downloadHandler` block (lines 177–184 pre-edit) with:

```r
  output$download1 <- downloadHandler(
    filename = function() {
      safe_good <- str_replace_all(input$good, "[^[:alnum:]]+", "_")
      paste0("inide_canasta_basica_", safe_good, "_", Sys.Date(), ".csv")
    },
    content = function(file) {
      write.csv(filtered_data(), file, row.names = FALSE)
    }
  )
```

(`stringr` is already loaded at line 8. `"Brassier/sostén"` becomes
`Brassier_sost_n` — ASCII-safe for downloads on every platform.)

**Verify**: `grep -n "safe_good" app.R` → two matches inside the handler;
`grep -n "row.names = FALSE" app.R` → one match.

### Step 6: Smoke test

```bash
Rscript -e 'invisible(parse("app.R"))'
Rscript -e 'app <- source("app.R")$value; stopifnot(inherits(app, "shiny.appobj")); cat("app ok\n")'
```

**Verify**: both exit 0; second prints `app ok`. The smoke test executes all
top-level code (libraries, data load, `grouped_data`, UI construction) —
only the reactive server internals need the optional manual run.

If you can run interactively, also: `Rscript -e 'shiny::runApp(".", port = 4242)'`,
open http://localhost:4242, and confirm (a) Copy/CSV/Excel/PDF/Print buttons
appear above both tables, (b) selecting "Fósforos" renders a single-line
title, (c) downloading "Brassier/sostén" produces a cleanly named CSV with no
leading row-number column. If no interactive environment is available, note
that in your report.

## Test plan

No test framework exists in this repo and `app.R` is a single deployable
script — the smoke test in Step 6 (app object builds, data loads) plus the
grep gates are the executable verification. Manual checks listed in Step 6
cover the reactive behavior; flag them for the reviewer if skipped.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `Rscript -e 'app <- source("app.R")$value; stopifnot(inherits(app, "shiny.appobj"))'` exits 0
- [ ] `grep -c "extensions = 'Buttons'" app.R` → 2
- [ ] `grep -c "renderDataTable\|dataTableOutput" app.R` → 0
- [ ] `grep -c "library(readr)" app.R` → 1
- [ ] `grep -n "safe_good" app.R` shows the sanitized filename
- [ ] `git status --porcelain` shows only `app.R` modified
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The smoke test fails after your edits with an error you cannot attribute
  to a specific edit within two attempts.
- `app.R` at the cited line ranges doesn't match the excerpts (drift).
- A required package is missing locally and `install.packages()` for it fails.

## Maintenance notes

- The app redeploys via GitHub Actions (schedule/manual) — these fixes reach
  production on the next deploy, no extra action needed.
- Plan 002 standardizes the Fósforos medida in the data; Step 3's `[1]` guard
  stays anyway as defense against future INIDE inconsistencies.
- Reviewer should scrutinize: that `DT::renderDT`/`DT::DTOutput` were swapped
  in pairs (a mismatched pair renders an empty table).
- Deferred (noted for a future direction plan): the sidebar text promises
  three canasta categories but the app offers no category view; and the app
  shows nominal prices only.

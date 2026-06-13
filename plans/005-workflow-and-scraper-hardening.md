# Plan 005: Harden the GitHub Actions workflow and the URL scraper

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 458d8cd..HEAD -- .github/workflows/update-data.yml 02_scrape_auto.R`
> Plans 001 (adds a workflow step) and 002 (removes lines 18–105 of
> 02_scrape_auto.R) are EXPECTED to have landed first — their changes are not
> drift. This plan therefore anchors edits to symbols and step names, not
> line numbers. If the *excerpted code itself* differs (not just its line
> position), treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED (deploy-path changes can only be fully verified by a live workflow run)
- **Depends on**: plans/002-single-source-cleaning-function.md (same file); plans/001-data-validation-gate.md (workflow step ordering)
- **Category**: dx + security
- **Planned at**: commit `458d8cd`, 2026-06-12

## Why this matters

Five compounding issues in the automation:

1. **Data is up to a month stale.** The cron runs once, on the 15th
   (`update-data.yml:6`). If INIDE publishes on the 16th, the repo and app
   lag ~30 days. The scrape script already short-circuits cheaply when there
   is nothing new (`no_data_changes.flag`), so running weekly costs almost
   nothing and cuts worst-case staleness to 7 days.
2. **Every scheduled run deploys**, even when nothing changed
   (`update-data.yml:106–120`, comment: "Always deploy on scheduled runs").
   The deploy path re-installs ~15 packages from scratch via a bare
   `renv::init` — roughly 10–15 minutes of CI and a fresh failure surface per
   month for zero content change. With a weekly cron this quadruples unless
   deploys become conditional.
3. **Secrets are interpolated into a command string**
   (`update-data.yml:153`): `token='${{secrets.SHINYAPPS_TOKEN}}'` inside an
   inline R script. GitHub masks log output, but the value lands in the
   spawned process's command line (visible to e.g. `ps` on the runner).
   Passing via `env:` and `Sys.getenv()` is the documented practice.
4. **No `permissions:` block.** The job pushes commits with the default
   token grant; least-privilege is to declare `contents: write` explicitly —
   this also keeps the workflow working if the repo/org default is ever
   tightened to read-only.
5. **The scraper trusts the INIDE page's link format**
   (`02_scrape_auto.R`, `get_available_urls()`): it prefixes every href with
   the domain (breaks on absolute hrefs → double-prefixed URLs) and lets
   unrecognized month strings flow through into `yymm`/`month` labels
   (`case_when(... TRUE ~ month_raw)` followed by a filter that can never
   drop them, since `month` is never NA there).

## Current state

- `.github/workflows/update-data.yml` (at `458d8cd`, before plan 001's
  added step):
  - Lines 3–7 (trigger):
    ```yaml
    on:
      schedule:
        # Run on the 15th of each month at 10:00 AM UTC
        - cron: "0 10 15 * *"
      workflow_dispatch: # Allow manual triggering for testing
    ```
  - No top-level `permissions:` anywhere (`grep -n permissions` → no match).
  - Lines 106–120, step `Check if app deployment needed` (id `check-deploy`):
    deploys whenever the event is `schedule` or `workflow_dispatch`,
    regardless of the `check-data-changes` output.
  - Lines 147–171, step `Deploy to shinyapps.io`: inline R with
    `rsconnect::setAccountInfo(name='rrmaximiliano', token='${{secrets.SHINYAPPS_TOKEN}}', secret='${{secrets.SHINYAPPS_SECRET}}')`.

- `02_scrape_auto.R`, function `get_available_urls()` (lines 109–159 at
  `458d8cd`; ~86 lines earlier once plan 002 lands):
  ```r
      links <- page %>%
        html_nodes("a[href*='CB']") %>%
        html_attr("href") %>%
        str_subset("\\.(xls|xlsx)$") %>%
        unique()

      # Convert relative URLs to absolute
      full_urls <- paste0("https://www.inide.gob.ni", links)
  ```
  and further down, after the month `case_when` ending in `TRUE ~ month_raw`:
  ```r
        filter(!is.na(year), !is.na(month)) %>%
  ```

- `02_scrape_auto.R`, last lines of the script (388–391 at `458d8cd`) — a
  log line that picks "latest month" by storage order, not calendar order:
  ```r
  latest_year <- max(all_data$year)
  latest_months <- all_data$month[all_data$year == latest_year]
  latest_month <- latest_months[length(latest_months)]
  cat("Latest data point:", latest_year, latest_month, "\n")
  ```

- rvest is loaded by the script (line 15) and depends on xml2, so
  `xml2::url_absolute()` is available without new dependencies.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| YAML check | `Rscript -e 'invisible(yaml::read_yaml(".github/workflows/update-data.yml")); cat("yaml ok\n")'` | `yaml ok`, exit 0 |
| R syntax check | `Rscript -e 'invisible(parse("02_scrape_auto.R"))'` | no output, exit 0 |
| Live scraper check (optional, needs network) | see Step 5 | tibble summary, all months valid |
| Secret-literal check | `grep -n "secrets.SHINYAPPS" .github/workflows/update-data.yml` | matches only on `env:`-block lines |

## Scope

**In scope** (the only files you should modify):
- `.github/workflows/update-data.yml`
- `02_scrape_auto.R` (only `get_available_urls()` and the final log lines)

**Out of scope** (do NOT touch, even though they look related):
- The `Prepare deployment directory with renv` step's *internals* — replacing
  the renv-init dance needs a live deploy to verify; explicitly deferred
  (see Maintenance notes).
- `r-version: "4.3.2"` — bumping CI's R version is an operator decision with
  its own failure modes; leave it (see Maintenance notes).
- `R/clean_canasta_data.R`, `scripts/`, `app.R`, `data/` — other plans.
- The `get_data_safe()` Excel-parsing function — its failures are caught and
  surfaced; plan 001's validation gate covers silent garbage.

## Git workflow

- Branch: `advisor/005-workflow-hardening`
- One commit is fine; suggested message: `Harden workflow: weekly cron, conditional deploy, env secrets, scraper URL fixes`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Workflow — permissions, cron, conditional deploy

In `.github/workflows/update-data.yml`:

1. Add a `permissions` block between `name:` and `on:`:
   ```yaml
   permissions:
     contents: write
   ```
2. Change the cron from monthly to weekly (Mondays 10:00 UTC) and update the
   comment:
   ```yaml
   on:
     schedule:
       # Run every Monday at 10:00 AM UTC; the scrape script exits early
       # via no_data_changes.flag when INIDE has not published a new month
       - cron: "0 10 * * 1"
     workflow_dispatch: # Allow manual triggering for testing
   ```
3. Replace the body of the `Check if app deployment needed` step (keep the
   step name and `id: check-deploy`) so scheduled runs deploy **only when
   data changed**, while manual runs always deploy (needed to ship app-code
   changes like plan 004):
   ```yaml
         - name: Check if app deployment needed
           id: check-deploy
           run: |
             if [ "${{ github.event_name }}" == "workflow_dispatch" ]; then
               echo "deploy=true" >> $GITHUB_OUTPUT
               echo "Deploying: manual run"
             elif [ "${{ steps.check-data-changes.outputs.data_changed }}" == "true" ]; then
               echo "deploy=true" >> $GITHUB_OUTPUT
               echo "Deploying: new data this run"
             else
               echo "deploy=false" >> $GITHUB_OUTPUT
               echo "Skipping deployment: no new data"
             fi
   ```

**Verify**: the YAML check command → `yaml ok`;
`grep -n "contents: write" .github/workflows/update-data.yml` → one match;
`grep -n "0 10 \* \* 1" .github/workflows/update-data.yml` → one match.

### Step 2: Workflow — secrets via environment variables

In the `Deploy to shinyapps.io` step, add an `env:` block and switch the
inline R to `Sys.getenv()`. Target shape (preserve the existing `if:`
condition and the second Rscript block that runs `deployApp` from
`deploy_temp` — only the account-info part changes):

```yaml
      - name: Deploy to shinyapps.io
        if: steps.check-deploy.outputs.deploy == 'true'
        env:
          SHINYAPPS_NAME: rrmaximiliano
          SHINYAPPS_TOKEN: ${{ secrets.SHINYAPPS_TOKEN }}
          SHINYAPPS_SECRET: ${{ secrets.SHINYAPPS_SECRET }}
        run: |
          # Install rsconnect globally
          Rscript -e "
            install.packages('rsconnect', repos = 'https://cloud.r-project.org/')
            rsconnect::setAccountInfo(
              name   = Sys.getenv('SHINYAPPS_NAME'),
              token  = Sys.getenv('SHINYAPPS_TOKEN'),
              secret = Sys.getenv('SHINYAPPS_SECRET')
            )
          "
          ...rest of the step unchanged...
```

**Verify**: `grep -n "secrets.SHINYAPPS" .github/workflows/update-data.yml`
→ exactly 2 matches, both on `env:`-block lines (`SHINYAPPS_TOKEN:` /
`SHINYAPPS_SECRET:`), none inside a `run:` script; YAML check → `yaml ok`.

### Step 3: Scraper — robust URL absolutization

In `02_scrape_auto.R`, `get_available_urls()`, replace:

```r
    # Convert relative URLs to absolute
    full_urls <- paste0("https://www.inide.gob.ni", links)
```

with:

```r
    # Convert relative URLs to absolute (no-op for already-absolute hrefs)
    full_urls <- xml2::url_absolute(links, "https://www.inide.gob.ni/")
```

**Verify**: `grep -n "url_absolute" 02_scrape_auto.R` → one match;
`grep -n 'paste0("https://www.inide.gob.ni"' 02_scrape_auto.R` → no matches.

### Step 4: Scraper — reject unrecognized month labels; fix the closing log line

1. In `get_available_urls()`, the month `case_when` ends with
   `TRUE ~ month_raw` and is followed by
   `filter(!is.na(year), !is.na(month))`. Since `month` can never be NA
   there, unrecognized labels (a renamed INIDE file pattern) flow into the
   dataset. Replace that filter line with:

   ```r
      filter(
        !is.na(year),
        month %in% c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
                     "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")
      ) %>%
   ```

   (An unparseable month now means "skip that file this run"; if INIDE
   renames its pattern wholesale, the run finds 0 new files and the log
   shows it — a visible, diagnosable failure instead of garbage labels.)

2. Replace the last four lines of the script (the `latest_year` /
   `latest_months` / `latest_month` / `cat` block quoted in "Current state")
   with calendar-ordered selection:

   ```r
   month_levels <- c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
                     "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")
   latest <- all_data[order(all_data$year, match(all_data$month, month_levels)), ]
   cat("Latest data point:", tail(latest$year, 1), as.character(tail(latest$month, 1)), "\n")
   ```

**Verify**: `Rscript -e 'invisible(parse("02_scrape_auto.R"))'` → exit 0;
`grep -n "month %in%" 02_scrape_auto.R` → one match inside
`get_available_urls`.

### Step 5: Live scraper check (optional — requires network)

Confirm `get_available_urls()` still finds the INIDE files:

```bash
Rscript -e '
  suppressPackageStartupMessages({library(dplyr); library(stringr); library(tibble); library(rvest)})
  e <- new.env(); src <- parse("02_scrape_auto.R")
  # evaluate only library calls and function definitions, not the main execution
  for (x in src) if (is.call(x) && (identical(x[[1]], as.name("library")) || (identical(x[[1]], as.name("<-")) && is.call(x[[3]]) && identical(x[[3]][[1]], as.name("function"))))) eval(x, e)
  urls <- e$get_available_urls()
  cat("files found:", nrow(urls), "\n")
  stopifnot(nrow(urls) > 150, all(urls$month %in% c("Ene","Feb","Mar","Abr","May","Jun","Jul","Ago","Sep","Oct","Nov","Dic")), all(startsWith(urls$url, "https://www.inide.gob.ni/")))
  cat("scraper ok\n")'
```

**Verify**: prints `files found: <n>` (>150) and `scraper ok`, exit 0.
If the INIDE site is unreachable, skip and record that in your report —
do not treat network failure as a code failure.

### Step 6: Hand off the live-run verification to the operator

The deploy-path changes (Steps 1–2) cannot be exercised locally. In your
completion report, tell the operator to run the workflow once manually
(`gh workflow run update-data.yml` or the Actions UI "Run workflow" button)
and check: the job goes green, secrets resolve (the `setAccountInfo` call
succeeds), and — being a manual run — it deploys. Do **not** trigger the
workflow yourself.

## Test plan

No test framework applies to workflow YAML. The executable verification is:
YAML parse + grep gates (Steps 1–2), R parse (Steps 3–4), the optional live
scraper check (Step 5), and the operator's manual workflow run (Step 6).
If plan 001 landed, `Rscript scripts/validate_data.R` must still pass
(this plan does not touch data, so it cannot regress it).

## Done criteria

Machine-checkable. ALL must hold:

- [ ] YAML check exits 0
- [ ] `grep -c "contents: write" .github/workflows/update-data.yml` → 1
- [ ] cron line is `"0 10 * * 1"`
- [ ] `grep -n "secrets.SHINYAPPS" .github/workflows/update-data.yml` shows matches only in the `env:` block
- [ ] deploy condition references `steps.check-data-changes.outputs.data_changed`
- [ ] `grep -c "url_absolute" 02_scrape_auto.R` → 1 and `Rscript -e 'invisible(parse("02_scrape_auto.R"))'` exits 0
- [ ] `git status --porcelain` shows only the two in-scope files modified
- [ ] `plans/README.md` status row updated, including a note that a manual workflow run is pending operator action

## STOP conditions

Stop and report back (do not improvise) if:

- The workflow file's `check-deploy` or deploy steps differ structurally
  from the excerpts (beyond plan 001's added `Validate data` step).
- `02_scrape_auto.R` still contains an inline `clean_canasta_data` function
  (plan 002 has not landed — land it first; both plans edit this file).
- Step 5's live check finds 0 files or invalid months *with the unmodified
  parsing logic too* (i.e. INIDE changed their site — that's a new finding,
  not something to patch ad hoc here).

## Maintenance notes

- **Deferred — renv deploy simplification**: the deploy step rebuilds a bare
  renv project and installs ~15 unpinned packages on every deploy. The
  better shape is a committed lockfile or plain `rsconnect::deployApp()`
  dependency detection, but changing it requires a live deploy to verify.
  Do it as its own change, watched by the operator.
- **Deferred — CI R version**: CI pins R 4.3.2 while the maintainer runs
  4.5.2 locally. Bump deliberately some quiet month, watching the package
  install step.
- After this lands, the first few weekly runs are worth a glance: three of
  four should short-circuit ("No new data") in ~5 minutes and not deploy.
- Reviewer should scrutinize: the deploy `if:` still fires on
  `workflow_dispatch` (otherwise app-code changes have no path to
  production), and that the commit step's behavior is unchanged.

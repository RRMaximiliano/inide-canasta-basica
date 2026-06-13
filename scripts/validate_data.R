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
EXPECTED_CATS <- c("Alimentos", "Usos del Hogar", "Vestuario")
EXPECTED_CAT_COUNTS <- c(Alimentos = 23, "Usos del Hogar" = 15, Vestuario = 15)

failures <- character(0)
fail <- function(msg) failures <<- c(failures, msg)
notes <- character(0)
note <- function(msg) notes <<- c(notes, msg)

if (!file.exists(path)) {
  cat("DATA VALIDATION FAILED:", path, "does not exist\n")
  quit(status = 1)
}

d <- readRDS(path)
d$month     <- as.character(d$month)
d$row       <- as.character(d$row)
d$categoria <- as.character(d$categoria)

# 1. Required columns
required <- c("yymm", "year", "month", "url", "row", "good", "medida",
              "cantidad", "precio", "total", "ym",
              "categoria", "ipc", "ipc_estimado", "precio_real", "total_real")
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
for (col in c("year", "month", "good", "medida", "cantidad", "precio",
              "total", "ym", "categoria", "ipc", "precio_real", "total_real")) {
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

# 7. Monthly series contiguity. A gap is reported as a NOTE, not a failure:
# INIDE occasionally does not publish a given month, and that legitimate
# source gap must not permanently block the automated pipeline.
mnum <- match(d$month, MONTH_LEVELS)
idx <- sort(unique(d$year * 12 + (mnum - 1)))
gap_after <- idx[which(diff(idx) != 1)]
if (length(gap_after) > 0) {
  gap_lbl <- vapply(gap_after,
                    function(i) sprintf("%s %d", MONTH_LEVELS[i %% 12 + 1], i %/% 12),
                    character(1))
  note(sprintf("%d gap(s) in the monthly series (missing month after: %s)",
               length(gap_after), paste(gap_lbl, collapse = ", ")))
}

# 8. Strictly positive values (nominal and real)
for (col in c("cantidad", "precio", "total", "ipc",
              "precio_real", "total_real")) {
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

# 11. Category dimension: only expected categories, correct counts per month
bad_cats <- setdiff(unique(d$categoria), EXPECTED_CATS)
if (length(bad_cats) > 0)
  fail(paste("unexpected categories:", paste(bad_cats, collapse = ", ")))
cat_by_month <- table(ym_key, d$categoria)
for (cat in names(EXPECTED_CAT_COUNTS)) {
  if (cat %in% colnames(cat_by_month)) {
    wrong <- sum(cat_by_month[, cat] != EXPECTED_CAT_COUNTS[[cat]])
    if (wrong > 0)
      fail(sprintf("%d month(s) where '%s' count != %d",
                   wrong, cat, EXPECTED_CAT_COUNTS[[cat]]))
  }
}

# 12. ipc_estimado is logical and only TRUE for trailing months
if (!is.logical(d$ipc_estimado))
  fail("ipc_estimado is not logical")

# Report -------------------------------------------------------------------
if (length(notes) > 0) {
  cat("NOTES:\n")
  cat(paste(" -", notes), sep = "\n")
  cat("\n")
}

if (length(failures) > 0) {
  cat("DATA VALIDATION FAILED for", path, "\n")
  cat(paste(" -", failures), sep = "\n")
  cat("\n")
  quit(status = 1)
}

fmt <- function(i) sprintf("%s %d", MONTH_LEVELS[i %% 12 + 1], i %/% 12)
n_est <- length(unique(ym_key[d$ipc_estimado]))
cat(sprintf(paste0("PASS: %d rows | %d months | %s -> %s | %d unique goods | ",
                   "3 categories | %d months with estimated IPC\n"),
            nrow(d), length(counts), fmt(min(idx)), fmt(max(idx)),
            n_goods, n_est))

# Characterization + invariant test for the shared cleaning function.
# Run from the repo root: Rscript tests/test_clean_canasta_data.R
#
# 1. clean_canasta_data() applied to the committed RAW data must reproduce the
#    cleaning-relevant columns of the committed CLEANED data (regression guard
#    for the row-keyed disambiguation refactor).
# 2. Core invariants: 53 unique goods, one medida per good, the four
#    disambiguated variants present in every month.

suppressPackageStartupMessages({
  library(dplyr); library(forcats); library(stringr); library(lubridate)
})
source("R/clean_canasta_data.R")

raw      <- readRDS("data/CB_FULL_raw.rds")
expected <- readRDS("data/CB_FULL.rds")
actual   <- clean_canasta_data(raw)

# --- 1. Reproduce committed cleaned columns ------------------------------
clean_cols <- intersect(names(actual), names(expected))
stopifnot(nrow(actual) == nrow(expected))
for (col in clean_cols) {
  a <- actual[[col]]; e <- expected[[col]]
  same <- if (is.numeric(a) && is.numeric(e)) {
    isTRUE(all.equal(a, e))
  } else {
    identical(as.character(a), as.character(e))
  }
  if (!same) stop("column differs from committed data: ", col)
}

# --- 2. Invariants -------------------------------------------------------
stopifnot(length(unique(actual$good)) == 53)

medidas_per_good <- actual %>%
  distinct(good, medida) %>%
  count(good) %>%
  filter(n > 1)
if (nrow(medidas_per_good) > 0)
  stop("goods with more than one medida: ",
       paste(medidas_per_good$good, collapse = ", "))

n_months <- length(unique(actual$ym))
for (g in c("Calcetines (Hombre)", "Calcetines (Niños y Niñas)",
            "Pantalón largo de tela de jeans (Hombre)",
            "Pantalón largo de tela de jeans (Mujeres)")) {
  n <- sum(actual$good == g)
  if (n != n_months)
    stop(sprintf("expected '%s' in all %d months, found %d", g, n_months, n))
}

cat(sprintf("PASS: cleaning reproduces committed data; 53 goods, 1 medida each, variants in all %d months\n",
            n_months))

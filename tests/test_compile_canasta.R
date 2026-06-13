# Tests for the category dimension and real-price deflation.
# Run from the repo root: Rscript tests/test_compile_canasta.R

suppressPackageStartupMessages({
  library(dplyr); library(forcats); library(stringr); library(lubridate)
  library(readr); library(jsonlite); library(tibble)
})
source("R/compile_canasta.R")

raw <- readRDS("data/CB_FULL_raw.rds")
ipc <- load_ipc(refresh = FALSE)          # use committed cache, no network
out <- compile_canasta(raw, ipc = ipc)

# --- Categories ----------------------------------------------------------
stopifnot(!any(is.na(out$categoria)))
stopifnot(identical(levels(out$categoria),
                    c("Alimentos", "Usos del Hogar", "Vestuario")))

# Every good maps to exactly one category
gc <- out %>% distinct(good, categoria) %>% count(good) %>% filter(n > 1)
if (nrow(gc) > 0) stop("goods mapped to >1 category: ",
                       paste(gc$good, collapse = ", "))

# Each month has the official 23 / 15 / 15 split
bad <- out %>%
  count(ym, categoria) %>%
  mutate(expected = recode(as.character(categoria),
                           "Alimentos" = 23L, "Usos del Hogar" = 15L,
                           "Vestuario" = 15L)) %>%
  filter(n != expected)
if (nrow(bad) > 0) stop("months with wrong category counts: ", nrow(bad))

# --- Real prices ---------------------------------------------------------
stopifnot(all(c("ipc", "ipc_estimado", "precio_real", "total_real") %in% names(out)))
stopifnot(!any(is.na(out$precio_real)), !any(is.na(out$total_real)))
stopifnot(all(out$precio_real > 0), all(out$total_real > 0))
stopifnot(is.logical(out$ipc_estimado))

# Deflation identity: precio_real == precio * base_index / ipc
base_index <- mean(ipc$ipc[ipc$year == IPC_BASE_YEAR], na.rm = TRUE)
chk <- out %>%
  mutate(expected = precio * base_index / ipc,
         err = abs(expected - precio_real) / pmax(abs(precio_real), 1e-9))
stopifnot(max(chk$err) < 1e-9)

# In the base year, real ~ nominal (within rounding of monthly vs annual index)
base_yr <- out %>% filter(year == IPC_BASE_YEAR)
ratio <- base_yr$precio_real / base_yr$precio
stopifnot(all(ratio > 0.9 & ratio < 1.1))

cat(sprintf("PASS: 3 categories (23/15/15), real prices valid, base year %d, deflation identity holds\n",
            IPC_BASE_YEAR))

# Full compilation of the canasta basica dataset from raw scraped data.
# SINGLE SOURCE OF TRUTH for the end-to-end transform, composed from the
# focused modules. Sourced by 02_scrape_auto.R, scripts/fix_data.R and
# scripts/rebuild_data.R so every entry point produces an identical schema.
#
# Pipeline: clean names/structure -> assign official category -> deflate to
# real prices. Requires dplyr, forcats, stringr, lubridate, readr, jsonlite
# (callers load them).
#
# NOTE: run all entry points from the repository root (paths are root-relative).
source("R/clean_canasta_data.R")
source("R/categories.R")
source("R/ipc.R")

# Compile raw canasta data into the final cleaned, categorized, deflated
# dataset. `ipc` is the monthly IPC tibble from load_ipc(); when NULL it is
# loaded (with network fetch + cache fallback) here.
compile_canasta <- function(raw_data, ipc = NULL,
                            ipc_cache = "data/ipc_nicaragua.csv",
                            refresh_ipc = TRUE) {
  if (is.null(ipc)) ipc <- load_ipc(cache_path = ipc_cache, refresh = refresh_ipc)
  raw_data %>%
    clean_canasta_data() %>%
    add_categoria() %>%
    add_real_prices(ipc)
}

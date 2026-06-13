# Real (inflation-adjusted) prices for the canasta basica.
# SINGLE SOURCE OF TRUTH for the consumer price index (IPC) and the deflation
# logic. Sourced by R/compile_canasta.R and scripts/update_ipc.R.
# Requires: dplyr, stringr, readr, jsonlite (callers load them).
#
# Source: IMF International Financial Statistics (IFS), monthly CPI for
# Nicaragua (series M.NI.PCPI_IX, base 2010 = 100), retrieved via the keyless
# DBnomics JSON API. The series typically lags the canasta by a few months;
# trailing months without an official IPC carry forward the last observed
# index and are flagged with `ipc_estimado = TRUE`.

# Base period for real prices. Real prices are expressed in constant cordobas
# of this year's average price level (precio_real == precio when ipc equals the
# base-year average). Fixed so historical real prices do not drift when new
# months are added; bump deliberately to re-base, then regenerate the dataset.
IPC_BASE_YEAR <- 2024

DBNOMICS_IPC_URL <-
  "https://api.db.nomics.world/v22/series/IMF/IFS/M.NI.PCPI_IX?observations=1"

# Fetch the monthly IPC series from DBnomics. Returns a tibble
# (ym, year, month_num, ipc) sorted by date, or NULL on any failure (so the
# caller can fall back to the cached copy without aborting the pipeline).
fetch_ipc_series <- function(url = DBNOMICS_IPC_URL) {
  tryCatch({
    raw <- jsonlite::fromJSON(url, simplifyVector = TRUE)
    doc <- raw$series$docs
    period <- unlist(doc$period)
    value  <- unlist(doc$value)
    tibble(
      period = as.character(period),
      ipc    = suppressWarnings(as.numeric(value))
    ) %>%
      filter(!is.na(ipc), str_detect(period, "^[0-9]{4}-[0-9]{2}$")) %>%
      mutate(
        ym        = as.Date(paste0(period, "-01")),
        year      = as.integer(substr(period, 1, 4)),
        month_num = as.integer(substr(period, 6, 7))
      ) %>%
      select(ym, year, month_num, ipc) %>%
      arrange(ym)
  }, error = function(e) {
    message("IPC fetch failed: ", conditionMessage(e))
    NULL
  })
}

# Load the IPC series: try a fresh fetch, cache it on success, otherwise fall
# back to the committed cache. Never returns invalid data silently.
load_ipc <- function(cache_path = "data/ipc_nicaragua.csv", refresh = TRUE) {
  fetched <- if (refresh) fetch_ipc_series() else NULL
  if (!is.null(fetched) && nrow(fetched) > 0) {
    readr::write_csv(fetched, cache_path)
    return(fetched)
  }
  if (file.exists(cache_path)) {
    message("Using cached IPC series at ", cache_path)
    return(readr::read_csv(cache_path, show_col_types = FALSE) %>%
             mutate(ym = as.Date(ym)))
  }
  stop("No IPC data available: fetch failed and no cache at ", cache_path)
}

# Join the IPC and compute real prices in constant base-year cordobas.
# Adds columns: ipc (index used, 2010 = 100), ipc_estimado (logical, TRUE where
# the index was carried forward past the official series), precio_real, total_real.
add_real_prices <- function(data, ipc, base_year = IPC_BASE_YEAR) {
  ipc <- ipc %>% filter(!is.na(ipc)) %>% arrange(ym)
  if (nrow(ipc) == 0) stop("IPC series is empty")

  last_ym    <- max(ipc$ym)
  last_ipc   <- ipc$ipc[ipc$ym == last_ym][1]
  base_index <- mean(ipc$ipc[ipc$year == base_year], na.rm = TRUE)
  if (is.nan(base_index) || base_index <= 0)
    stop("No IPC data for base year ", base_year)

  data %>%
    left_join(ipc %>% select(ym, ipc), by = "ym") %>%
    mutate(
      ipc_estimado = is.na(ipc) & ym > last_ym,
      ipc          = if_else(ipc_estimado, last_ipc, ipc),
      precio_real  = precio * base_index / ipc,
      total_real   = total  * base_index / ipc
    )
}

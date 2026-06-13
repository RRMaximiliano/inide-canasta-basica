# Automated scraping script for continuous updates
# This script checks what data already exists and only downloads new data

# Packages ----------------------------------------------------------------

library(dplyr)
library(purrr)
library(stringr)
library(tibble)
library(readr)
library(forcats)
library(lubridate)
library(glue)
library(readxl)
library(rvest)
library(haven)
library(jsonlite)

# Data compilation (single source of truth) -------------------------------
# Cleaning, category assignment and real-price deflation all live in R/.
source("R/compile_canasta.R")

# Function to scrape available URLs from the website ---------------------

get_available_urls <- function() {
  tryCatch({
    # Scrape the main page
    page <- read_html("https://www.inide.gob.ni/Home/canasta")
    
    # Extract all CB file links
    links <- page %>%
      html_nodes("a[href*='CB']") %>%
      html_attr("href") %>%
      str_subset("\\.(xls|xlsx)$") %>%
      unique()
    
    # Convert relative URLs to absolute (no-op for already-absolute hrefs)
    full_urls <- xml2::url_absolute(links, "https://www.inide.gob.ni/")
    
    # Extract year and month from URLs
    url_data <- tibble(url = full_urls) %>%
      mutate(
        filename = str_extract(url, "CB[^/]+\\.(xls|xlsx)$"),
        # Year comes from the /CB{YYYY}/ directory in the path, which is always
        # 4 digits - far more reliable than the filename, where INIDE uses 2- or
        # 4-digit years inconsistently (e.g. CBMar26.xlsx vs CBFeb2026.xlsx).
        year = as.numeric(str_extract(str_extract(url, "/CB(\\d{4})/"), "\\d{4}")),
        # Month = the letters between the CB/C prefix and the trailing year
        # digits, tolerant of 2- or 4-digit years and full/abbreviated names.
        month_raw = filename %>%
          str_remove("\\.(xls|xlsx)$") %>%
          str_remove("^CB?") %>%
          str_remove("\\d+$") %>%
          str_remove("_"),
        month = case_when(
          str_detect(month_raw, "Ene|ene") ~ "Ene",
          str_detect(month_raw, "Feb|feb") ~ "Feb", 
          str_detect(month_raw, "Mar|mar") ~ "Mar",
          str_detect(month_raw, "Abr|abr") ~ "Abr",
          str_detect(month_raw, "May|may") ~ "May",
          str_detect(month_raw, "Jun|jun") ~ "Jun",
          str_detect(month_raw, "Jul|jul") ~ "Jul",
          str_detect(month_raw, "Ago|ago") ~ "Ago",
          str_detect(month_raw, "Sep|sep") ~ "Sep",
          str_detect(month_raw, "Oct|oct") ~ "Oct",
          str_detect(month_raw, "Nov|nov") ~ "Nov",
          str_detect(month_raw, "Dic|dic") ~ "Dic",
          TRUE ~ month_raw
        )
      ) %>%
      filter(
        !is.na(year),
        month %in% c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
                     "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")
      ) %>%
      arrange(year, match(month, c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
                                   "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")))
    
    url_data
    
  }, error = function(e) {
    cat("Error scraping website:", e$message, "\n")
      tibble()
  })
}

# Function to get existing data info --------------------------------------

get_existing_data_info <- function() {
  if(file.exists("data/CB_FULL.rds")) {
    existing_data <- read_rds("data/CB_FULL.rds")
    
    existing_info <- existing_data %>%
      select(year, month, url) %>%
      distinct() %>%
      arrange(year, match(month, c("Ene", "Feb", "Mar", "Abr", "May", "Jun", 
                                   "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")))
    
    existing_info
  } else {
    tibble(year = numeric(), month = character(), url = character())
  }
}

# Function to get data (same as before) ----------------------------------

get_data_safe <- function(url) {
  tryCatch({
    url.name   <- str_replace_all(url, ".*/", "")
    url.string <- as.character(url)
    temp_xls   <- tempfile()
    
    # Download file
    download.file(url.string, destfile = temp_xls, mode = "wb", quiet = TRUE)
    
    # Read Excel file
    temp <- read_excel(temp_xls) %>% 
      mutate(
        url = as.character(url)
      ) %>% 
      rename(
        row = 1,
        bien = 2,
        medida = 3,
        cantidad = 4,
        precio = 5,
        total = 6
      ) %>% 
      select(1:6, url) %>% 
      mutate(
        across(
          where(is.character),
          ~ na_if(.x, "")
        )
      ) %>% 
      filter(
        !is.na(row),
        !is.na(bien),
        !str_detect(bien, "Descrip")
      ) %>% 
      mutate(
        across(
          c(4:6),
          ~ str_replace_all(.x, ",", "") %>%
            as.numeric(.x) 
        ),
        bien = str_trim(bien)
      ) %>% 
      as_tibble()
    
    # Clean up temp file
    unlink(temp_xls)
    
    temp
    
  }, error = function(e) {
    cat("Error processing", url, ":", e$message, "\n")
    return(NULL)
  })
}

# Main execution ----------------------------------------------------------

cat("Starting automated data update...\n")

# Get available URLs from website
cat("Scraping available URLs from website...\n")
available_urls <- get_available_urls()

if(nrow(available_urls) == 0) {
  cat("No URLs found on website. Exiting.\n")
  quit(status = 1)
}

cat("Found", nrow(available_urls), "files on website\n")

# Get existing data info
existing_info <- get_existing_data_info()
cat("Found", nrow(existing_info), "existing data files\n")

# Find new URLs to download
if(nrow(existing_info) > 0) {
  new_urls <- available_urls %>%
    anti_join(existing_info, by = c("year", "month"))
} else {
  new_urls <- available_urls
}

cat("Found", nrow(new_urls), "new files to download\n")

if(nrow(new_urls) == 0) {
  cat("No new data to download. Data is up to date.\n")
  # Create a flag file to indicate no changes for GitHub Actions
  writeLines("no-changes", "no_data_changes.flag")
  quit(status = 0)
}

# Download new data
cat("Downloading new data...\n")
new_data_list <- map(new_urls$url, function(url) {
  cat("Processing:", url, "\n")
  get_data_safe(url)
})

# Remove NULL entries (failed downloads)
new_data_list <- new_data_list[!sapply(new_data_list, is.null)]

if(length(new_data_list) == 0) {
  cat("Failed to download any new data.\n")
  quit(status = 1)
}

# Combine new data
new_dfs <- bind_rows(new_data_list)

# Add month and year labels
clean_new_df <- new_dfs %>% 
  left_join(new_urls, by = "url") %>% 
  mutate(
    yymm = glue("CB{year}{month}")
  ) %>% 
  select(
    yymm, year, month, url, everything(), -filename, -month_raw
  )

cat("Successfully processed", nrow(clean_new_df), "rows of new data\n")

# Export individual monthly files
clean_new_df_list <- clean_new_df %>% 
  group_by(yymm) %>% 
  {setNames(group_split(.), group_keys(.)[[1]])}

# Create monthly directory if it doesn't exist
if(!dir.exists("data/monthly")) {
  dir.create("data/monthly", recursive = TRUE)
}

clean_new_df_list %>% 
  names(.) %>% 
  map(
    ~ write.csv(
      clean_new_df_list[[.]], 
      file.path("data/monthly/", paste0(., ".csv")),
      row.names = FALSE
    )
  )

# Load existing data and combine
# IMPORTANT: Load the RAW version to avoid column name mismatches
if(file.exists("data/CB_FULL_raw.rds")) {
  cat("Loading existing raw data...\n")
  old_data <- read_rds("data/CB_FULL_raw.rds")
  
  # Ensure both old and new data have the same column structure
  # Rename 'good' to 'bien' in old data if needed to match new data structure
  if("good" %in% names(old_data) && !"bien" %in% names(old_data)) {
    cat("Renaming 'good' to 'bien' in old data for consistency...\n")
    old_data <- old_data %>% rename(bien = good)
  }

  # Ensure consistent column types before binding
  # The 'row' column may be numeric in old data but character in new Excel data
  old_data <- old_data %>% mutate(row = as.character(row))
  clean_new_df <- clean_new_df %>% mutate(row = as.character(row))

  # Combine old and new data
  all_data <- old_data %>%
    bind_rows(clean_new_df)
} else {
  all_data <- clean_new_df
}

cat("Combined dataset now has", nrow(all_data), "rows\n")

# Compile: clean + assign categories + deflate to real prices
cat("Compiling dataset (clean + categories + real prices)...\n")
cat("Column names before compiling:", paste(names(all_data), collapse = ", "), "\n")
all_data_cleaned <- compile_canasta(all_data)
cat("Column names after compiling:", paste(names(all_data_cleaned), collapse = ", "), "\n")

# Export updated full dataset (both raw and cleaned versions)
cat("Saving updated datasets...\n")

# Save raw version (for backup/reference)
all_data %>% 
  write.csv(
    "data/CB_FULL_raw.csv",
    row.names = FALSE
  )

all_data %>% 
  write_rds(
    "data/CB_FULL_raw.rds"
  )

# Save cleaned version (main dataset)
all_data_cleaned %>% 
  write.csv(
    "data/CB_FULL.csv",
    row.names = FALSE
  )

all_data_cleaned %>% 
  write_rds(
    "data/CB_FULL.rds"
  )

all_data_cleaned %>% 
  write_dta(
    "data/CB_FULL.dta"
  )

cat("Data update completed successfully!\n")
month_levels <- c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
                  "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")
latest <- all_data_cleaned[order(all_data_cleaned$year,
                                 match(as.character(all_data_cleaned$month), month_levels)), ]
cat("Latest data point:", tail(latest$year, 1),
    as.character(tail(latest$month, 1)), "\n")
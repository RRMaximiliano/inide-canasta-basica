# Automated scraping script for continuous updates
# This script checks what data already exists and only downloads new data

# Packages ----------------------------------------------------------------

library(tidyverse)
library(janitor)
library(lubridate)
library(rio)
library(glue)
library(gdata)
library(haven)
library(readxl)
library(rvest)

# Data cleaning function ------------------------------------------------

clean_canasta_data <- function(data) {
  cleaned_data <- data %>% 
    # Rename bien to good for consistency
    rename(good = bien) %>% 
    
    # Set proper factor levels for months
    mutate(
      month = fct_relevel(
        month, 
        "Ene", "Feb", "Mar", "Abr", "May", "Jun", 
        "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"
      )
    ) %>%
    
    # Clean good names and standardize variations
    mutate(
      good = str_squish(good),
      good = case_when(
        str_detect(good, "Brassier") ~ "Brassier/sostén",
        str_detect(good, "Desodorante") ~ "Desodorante nacional",
        str_detect(good, "Pasta dental") ~ "Pasta dental",
        str_detect(good, "Pastas dental") ~ "Pasta dental",
        str_detect(good, "cuero natural") ~ "Zapato de cuero natural",
        # Consolidate duplicate goods to get to 53 unique items
        str_detect(good, "Detergente en polvo") ~ "Detergente",
        str_detect(good, "^Detergente$") ~ "Detergente",
        str_detect(good, "Jabón de lavar ropa") ~ "Jabón de lavar ropa",
        str_detect(good, "^Jabón de lavar$") ~ "Jabón de lavar ropa",
        str_detect(good, "Leche fluída") ~ "Leche",
        str_detect(good, "^Leche$") ~ "Leche",
        str_detect(good, "Chuleta de pescado") ~ "Chuleta de pescado",
        str_detect(good, "^Pescado$") ~ "Chuleta de pescado",
        TRUE ~ good
      )
    ) %>% 
    
    # Create year-month variable for grouping
    mutate(
      ym = paste0(year, "-", as.numeric(month)),
      ym = ym(ym)
    ) %>% 
    
    # Add row ID within each month for specific item disambiguation
    group_by(ym) %>% 
    mutate(
      rowid = row_number()
    ) %>% 
    ungroup() %>% 
    
    # Disambiguate items that appear multiple times with different specifications
    mutate(
      good = case_when(
        good == "Calcetines" & rowid == 42 ~ "Calcetines (Hombre)",
        good == "Calcetines" & rowid == 52 ~ "Calcetines (Niños y Niñas)",
        good == "Pantalón largo de tela de jeans" & rowid == 39 ~ "Pantalón largo de tela de jeans (Hombre)",
        good == "Pantalón largo de tela de jeans" & rowid == 45 ~ "Pantalón largo de tela de jeans (Mujeres)",
        TRUE ~ good
      )
    ) %>% 
    
    # Clean medida and handle special cases for precio
    mutate(
      medida = str_to_lower(medida),
      precio = case_when(
        is.na(precio) & good == "Alquiler" ~ total, 
        TRUE ~ precio
      )
    ) %>%
    
    # Remove the temporary rowid column
    select(-rowid)
  
  return(cleaned_data)
}

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
    
    # Convert relative URLs to absolute
    full_urls <- paste0("https://www.inide.gob.ni", links)
    
    # Extract year and month from URLs
    url_data <- tibble(url = full_urls) %>%
      mutate(
        filename = str_extract(url, "CB[^/]+\\.(xls|xlsx)$"),
        year = as.numeric(str_extract(filename, "\\d{4}")),
        month_raw = str_extract(filename, "CB([A-Za-z_]+)\\d{4}") %>%
          str_remove("CB") %>%
          str_remove("\\d{4}") %>%
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
      filter(!is.na(year), !is.na(month)) %>%
      arrange(year, match(month, c("Ene", "Feb", "Mar", "Abr", "May", "Jun", 
                                   "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")))
    
    return(url_data)
    
  }, error = function(e) {
    cat("Error scraping website:", e$message, "\n")
    return(tibble())
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
    
    return(existing_info)
  } else {
    return(tibble(year = numeric(), month = character(), url = character()))
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
    
    return(temp)
    
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
if(file.exists("data/CB_FULL.rds")) {
  cat("Loading existing data...\n")
  old_data <- read_rds("data/CB_FULL.rds")
  
  # Combine old and new data
  all_data <- old_data %>% 
    bind_rows(clean_new_df)
} else {
  all_data <- clean_new_df
}

cat("Combined dataset now has", nrow(all_data), "rows\n")

# Apply data cleaning
cat("Applying data cleaning...\n")
all_data_cleaned <- clean_canasta_data(all_data)

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
latest_year <- max(all_data$year)
latest_months <- all_data$month[all_data$year == latest_year]
latest_month <- latest_months[length(latest_months)]
cat("Latest data point:", latest_year, latest_month, "\n")
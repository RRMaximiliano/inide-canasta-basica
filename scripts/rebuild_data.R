# Rebuild CB_FULL from monthly files
# This ensures all data is properly included

library(dplyr)
library(readr)
library(purrr)
library(forcats)
library(lubridate)
library(stringr)
library(haven)
library(glue)

cat("Rebuilding CB_FULL from monthly files...\n")

# Get all monthly CSV files
monthly_files <- list.files("data/monthly", pattern = "^CB.*\\.csv$", full.names = TRUE)
cat("Found", length(monthly_files), "monthly files\n")

# Read and combine all monthly files
cat("Reading monthly files...\n")
all_data <- map_df(monthly_files, function(file) {
  cat("  Reading:", basename(file), "\n")
  read_csv(file, show_col_types = FALSE)
})

cat("Combined", nrow(all_data), "rows from monthly files\n")
cat("Columns:", paste(names(all_data), collapse = ", "), "\n")

# Check for good/bien columns
if("good" %in% names(all_data)) {
  cat("Rows with NA in good column:", sum(is.na(all_data$good)), "\n")
}
if("bien" %in% names(all_data)) {
  cat("Rows with NA in bien column:", sum(is.na(all_data$bien)), "\n")
}

# Define the cleaning function inline (with the fix)
clean_canasta_data <- function(data) {
  cleaned_data <- data %>% 
    # Handle column naming - ensure we have 'good' column
    {
      if("bien" %in% names(.) && !"good" %in% names(.)) {
        # Case 1: Only 'bien' exists, rename it to 'good'
        rename(., good = bien)
      } else if("bien" %in% names(.) && "good" %in% names(.)) {
        # Case 2: Both exist, merge them (coalesce to get non-NA values from either)
        mutate(., good = coalesce(good, bien)) %>%
        select(., -bien)
      } else {
        # Case 3: Only 'good' exists or neither exists
        .
      }
    } %>% 
    
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
  
  cleaned_data
}

cat("\nApplying cleaning function...\n")
cleaned_data <- clean_canasta_data(all_data)

cat("After cleaning:\n")
cat("Columns:", paste(names(cleaned_data), collapse = ", "), "\n")
cat("Rows with NA in good column:", sum(is.na(cleaned_data$good)), "\n")

# Check the recent months
cat("\nChecking recent months (2025):\n")
recent <- cleaned_data %>%
  filter(year == 2025) %>%
  group_by(year, month) %>%
  summarize(
    total_rows = n(),
    rows_with_goods = sum(!is.na(good)),
    unique_goods = n_distinct(good, na.rm = TRUE),
    .groups = "drop"
  )
print(recent)

# Save the raw version (before cleaning)
cat("\nSaving datasets...\n")
all_data %>%
  write_csv("data/CB_FULL_raw.csv")

all_data %>%
  write_rds("data/CB_FULL_raw.rds")

# Save cleaned version (main dataset)
cleaned_data %>%
  write_csv("data/CB_FULL.csv")

cleaned_data %>%
  write_rds("data/CB_FULL.rds")

cleaned_data %>%
  write_dta("data/CB_FULL.dta")

cat("\n✅ Data successfully rebuilt from monthly files!\n")
cat("Total rows:", nrow(cleaned_data), "\n")
cat("Date range:", min(cleaned_data$year), "-", max(cleaned_data$year), "\n")
latest_data <- cleaned_data %>% arrange(desc(year), desc(match(month, c("Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")))) %>% slice(1)
cat("Latest data point:", latest_data$year, latest_data$month, "\n")

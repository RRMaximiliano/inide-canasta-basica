# Quick fix script to repair the CB_FULL dataset
# This script re-processes the raw data with the fixed cleaning function

library(dplyr)
library(readr)
library(forcats)
library(lubridate)
library(stringr)
library(haven)
library(glue)

cat("Loading raw data...\n")
raw_data <- read_rds("data/CB_FULL_raw.rds")

cat("Current structure:\n")
cat("Columns:", paste(names(raw_data), collapse = ", "), "\n")
cat("Rows with NA in good column:", sum(is.na(raw_data$good)), "\n")
if("bien" %in% names(raw_data)) {
  cat("Rows with NA in bien column:", sum(is.na(raw_data$bien)), "\n")
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

cat("\nApplying fixed cleaning function...\n")
cleaned_data <- clean_canasta_data(raw_data)

cat("After cleaning:\n")
cat("Columns:", paste(names(cleaned_data), collapse = ", "), "\n")
cat("Rows with NA in good column:", sum(is.na(cleaned_data$good)), "\n")

# Check the recent months
cat("\nChecking recent months:\n")
recent <- cleaned_data %>%
  filter(year == 2025, month %in% c("Jun", "Jul", "Ago", "Sep", "Oct")) %>%
  group_by(year, month) %>%
  summarize(
    total_rows = n(),
    rows_with_goods = sum(!is.na(good)),
    unique_goods = n_distinct(good, na.rm = TRUE),
    .groups = "drop"
  )
print(recent)

# Save the corrected data
cat("\nSaving corrected datasets...\n")
cleaned_data %>%
  write_csv("data/CB_FULL.csv")

cleaned_data %>%
  write_rds("data/CB_FULL.rds")

cleaned_data %>%
  write_dta("data/CB_FULL.dta")

cat("\n✅ Data successfully repaired!\n")
cat("Latest month:", max(cleaned_data$year), max(cleaned_data$month[cleaned_data$year == max(cleaned_data$year)]), "\n")

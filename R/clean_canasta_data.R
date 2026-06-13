# Canonical cleaning function for the canasta basica pipeline.
# SINGLE SOURCE OF TRUTH - sourced by R/compile_canasta.R (and therefore by
# 02_scrape_auto.R, scripts/fix_data.R, scripts/rebuild_data.R). Edit here only.
# Requires: dplyr, forcats, stringr, lubridate (callers load them).

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

    # Disambiguate items that appear multiple times, keyed on INIDE's
    # official item number (the `row` column) - stable in every month since
    # 2007, unlike positional row_number() which breaks if order changes
    mutate(
      good = case_when(
        good == "Calcetines" & as.character(row) == "42" ~ "Calcetines (Hombre)",
        good == "Calcetines" & as.character(row) == "52" ~ "Calcetines (Niños y Niñas)",
        good == "Pantalón largo de tela de jeans" & as.character(row) == "39" ~ "Pantalón largo de tela de jeans (Hombre)",
        good == "Pantalón largo de tela de jeans" & as.character(row) == "45" ~ "Pantalón largo de tela de jeans (Mujeres)",
        TRUE ~ good
      )
    ) %>%

    # Clean medida and handle special cases for precio
    mutate(
      medida = str_to_lower(medida),
      # INIDE spells Fósforos' unit both "cerillos" and "cerrillos";
      # standardize so every good has exactly one medida
      medida = str_replace(medida, "cerrillos", "cerillos"),
      precio = case_when(
        is.na(precio) & good == "Alquiler" ~ total,
        TRUE ~ precio
      )
    )

  cleaned_data
}

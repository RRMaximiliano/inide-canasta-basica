
# Packages ----------------------------------------------------------------

library(dplyr)
library(purrr)
library(stringr)
library(tibble)
library(readr)
library(lubridate)
library(rio)
library(glue)
library(gdata)
library(haven)
library(readxl)

# To list -----------------------------------------------------------------

list <- files %>% 
  select(url) %>% 
  transpose() %>% 
  flatten()

# Function ----------------------------------------------------------------

get_data <- function(url) {
  url.name   <- str_replace_all(url, ".*/", "")
  url.string <- as.character(url)
  temp_xls   <- tempfile()
  
  download.file(url.string, destfile = temp_xls, mode = "wb")
  
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
}

# Get data ----------------------------------------------------------------

list_reduc <- list[187:190]

dfs <- map_dfr(list_reduc, get_data)

# Getting month and year labels -------------------------------------------

clean_df <- dfs %>% 
  left_join(files, by = "url") %>% 
  mutate(
    yymm = glue("CB{year}{month}")
  ) %>% 
  select(
    yymm, year, month, url, everything()
  )

# Export to excel, each month per year ------------------------------------

clean_df_list <- clean_df %>% 
  group_by(yymm) %>% 
  {setNames(group_split(.), group_keys(.)[[1]])}

clean_df_list %>% 
  names(.) %>% 
  map(
    ~ write.csv(
      clean_df_list[[.]], 
      file.path("data/monthly/", paste0(., ".csv")),
      row.names = FALSE
    )
  )

old_data <- read_rds("data/CB_FULL.rds")
all_data <- old_data %>% 
  bind_rows(clean_df)
  
all_data %>% 
  write.csv(
    "data/CB_FULL.csv",
    row.names = FALSE
  )

all_data %>% 
  write_rds(
    "data/CB_FULL.rds"
  )

all_data %>% 
  write_dta(
    "data/CB_FULL.dta"
  )


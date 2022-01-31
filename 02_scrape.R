
# Packages ----------------------------------------------------------------

pacman::p_load(tidyverse, janitor, lubridate, rio, glue, gdata, haven)

# To list -----------------------------------------------------------------

list <- files %>% 
  select(url) %>% 
  transpose() %>% 
  flatten()

# Function ----------------------------------------------------------------

get_data <- function(url) {
  url.name   <- str_replace_all(url, ".*/", "")
  url.string <- as.character(url)
  temp_xls   <- tempfile(fileext = "xls")
  
  download.file(url.string, destfile = temp_xls, mode = "wb")
  
  temp <- read.xls(temp_xls) %>% 
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

dfs <- map_dfr(list, get_data)


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

clean_df %>% 
  write.csv(
    "data/CB_FULL.csv",
    row.names = FALSE
  )

clean_df %>% 
  write_rds(
    "data/CB_FULL.rds"
  )

clean_df %>% 
  write_dta(
    "data/CB_FULL.dta"
  )


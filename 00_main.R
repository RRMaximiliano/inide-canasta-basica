
# Packages ----------------------------------------------------------------

pacman::p_load(tidyverse, janitor, lubridate, rio, glue)

# Scrape data -------------------------------------------------------------

yy    = rep(2007:2021, each = 12)
mm    = rep(c("Ene","Feb","Mar","Abr","May","Jun","Jul","Ago","Sep","Oct","Nov","Dic"), 15) %>% 
  as_factor()
files = data.frame(month = mm, year = yy) %>% 
  arrange(year, month) %>% 
  mutate(
    id = row_number()
  ) %>% 
  filter(
    id >= 9
  ) %>% 
  select(-id) %>% 
  mutate(
    url = glue("https://www.inide.gob.ni/docs/CanastaB/CB{year}/CB{month}{year}.xls"),
    url = ifelse(
      year %in% c(2014:2019), str_replace_all(url, "docs/CanastaB", "docs/CanastaB/canastab"),
      url
    ),
    ## Fix Agosto 2014
    url = ifelse(
      year == 2014 & month == "Ago", str_replace_all(url, "Ago", "Agos"), url
    ),
    ## Fix ultimos meses del 2019
    url = ifelse(
      as.numeric(month) >= 7  & year == 2019,
      glue("https://www.inide.gob.ni/docs/CanastaB/CB{year}/CB{month}{year}.xls"),
      url
    ),
    ## Fix 2011, 2012, 2013
    url = ifelse(
      year %in% c(2011, 2012,2013),
      glue("https://www.inide.gob.ni/docs/CanastaB/canastab/CB{year}/C{month}{year}.xls"),
      url
    ),
    url = ifelse(
      month == "Abr" & year == 2012, str_replace(url, "Abr","Abril"), url
    ),
    url = ifelse(
      month == "May" & year == 2012, str_replace(url, "May","Mayo"),  url
    ),
    url = ifelse(
      month == "Jun" & year == 2012, str_replace(url, "Jun","Junio"), url
    ),
    url = ifelse(
      month == "Jul" & year == 2012, str_replace(url, "Jul","Julio"), url
    ),
    ## 2011 (Enero, Mayo)
    url = ifelse(
      month == "Ene" & year == 2011, str_replace(url, "Ene","Enero"),  url
    ),
    url = ifelse(
      month == "May" & year == 2011, str_replace(url, "May","may"),  url
    )
  ) %>% 
  filter(
    between(year, 2012,2021)
  )
    
# Get data ----------------------------------------------------------------

get_data <- function(x) {
  import(file = x, which = 1) %>% 
    # Cleaning
    rename(
      bien = 2,
      medida = 3,
      cantidad = 4,
      precio = 5,
      total = 6
    ) %>% 
    select(2:6) %>% 
    filter(
      !is.na(medida),
      !is.na(bien),
      !str_detect(bien, "Descrip")
    ) %>% 
    mutate(
      across(
        c(3:5),
        ~ str_trim(.x) %>% 
          as.numeric(.x) 
      )
    ) %>% 
    as_tibble()
  
}


# Save data ---------------------------------------------------------------

df <- files %>% 
  mutate(
    data = map(url, get_data)
  ) %>% 
  unnest(
    data
  )

write.csv(
  df,
  "data/canasta_basica_full.csv",
  row.names = FALSE
)

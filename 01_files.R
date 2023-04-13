
# Packages ----------------------------------------------------------------

pacman::p_load(tidyverse, janitor, lubridate, rio, glue, gdata, stringi)

# Scrape data -------------------------------------------------------------

yy    = rep(2007:2023, each = 12)
mm    = rep(c("Ene","Feb","Mar","Abr","May","Jun","Jul","Ago","Sep","Oct","Nov","Dic"), 17) %>% 
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
    ),
    url = ifelse(
      month == "Mar" & year == 2011, "http://www.inide.gob.ni/docs/CanastaB/canastab/CB2011/CMar2011.xls", url
    ),
    url = ifelse(
      month == "Oct" & year == 2011, "http://www.inide.gob.ni/docs/CanastaB/canastab/CB2011/COct2011.xls", url
    ),
    ## 2007
    url = ifelse(
      month == "Sep" & year == 2007,"https://www.inide.gob.ni/docs/CanastaB/canastab/CB2007/CSept07.xls", url
    ),
    url = ifelse(
      month == "Oct" & year == 2007,"https://www.inide.gob.ni/docs/CanastaB/canastab/CB2007/COct07.xls", url
    ),
    url = ifelse(
      month == "Nov" & year == 2007,"https://www.inide.gob.ni/docs/CanastaB/canastab/CB2007/CNOv07.xls", url
    ),
    url = ifelse(
      month == "Dic" & year == 2007,"https://www.inide.gob.ni/docs/CanastaB/canastab/CB2007/CDIc07.xls", url
    ),
    ## 2008
    url = ifelse(
      year == 2008, str_replace_all(url, "docs/CanastaB", "docs/CanastaB/canastab"), url
    ),
    url = ifelse(
      year == 2008, stri_replace_last_fixed(url, "20", ""), url
    ),
    url = ifelse(
      year == 2008, str_replace_all(url, "CB2008/CB", "CB2008/C"), url
    ),
    url = ifelse(
      month == "Mar" & year == 2008, str_replace_all(url, "Mar", "Marzo"), url
    ),
    url = ifelse(
      month == "Abr" & year == 2008, str_replace_all(url, "Abr","Abril"), url
    ),
    url = ifelse(
      month == "May" & year == 2008, str_replace_all(url, "May","Mayo"), url
    ),
    url = ifelse(
      month == "Jun" & year == 2008, str_replace(url, "Jun","Junio"), url
    ),
    url = ifelse(
      month == "Jul" & year == 2008, str_replace(url, "Jul","Julio"), url
    ),
    url = ifelse(
      month == "Ago" & year == 2008, str_replace(url, "Ago","Agos"), url
    ),
    url = ifelse(
      month == "Sep" & year == 2008, str_replace(url, "Sep","sept"), url
    ),
    url = ifelse(
      month == "Oct" & year == 2008, str_replace(url, "Oct","octubre"), url
    ),
    url = ifelse(
      month == "Dic" & year == 2008, str_replace(url, "Dic","diciembre"), url
    ),
    ## 2009
    url = ifelse(
      year == 2009, str_replace_all(url, "docs/CanastaB", "docs/CanastaB/canastab"), url
    ),
    url = ifelse(
      year == 2009, stri_replace_last_fixed(url, "20", ""), url
    ),
    url = ifelse(
      year == 2009, str_replace_all(url, "CB2009/CB", "CB2009/C"), url
    ),
    url = case_when(
      month == "Ene" & year == 2009 ~ str_replace(url, "Ene","enero"),
      month == "Feb" & year == 2009 ~ str_replace(url, "Feb","febrero"),
      month == "Mar" & year == 2009 ~ str_replace(url, "Mar","marzo"),
      month == "Abr" & year == 2009 ~ str_replace(url, "Abr","Abril"),
      month == "May" & year == 2009 ~ str_replace(url, "May","Mayo"),
      month == "Jun" & year == 2009 ~ str_replace(url, "Jun","Junio"),
      month == "Jul" & year == 2009 ~ str_replace(url, "Jul","Julio"),
      month == "Ago" & year == 2009 ~ str_replace(url, "Ago","agosto"),
      month == "Sep" & year == 2009 ~ str_replace(url, "Sep","septiembre"),
      month == "Oct" & year == 2009 ~ str_replace(url, "Oct","octubre"),
      month == "Dic" & year == 2009 ~ str_replace(url, "Dic","diciembre"),
      TRUE ~ url
    ),
    ## 2010
    url = ifelse(
      year == 2010, str_replace_all(url, "docs/CanastaB", "docs/CanastaB/canastab"), url
    ),
    url = ifelse(
      year == 2010, str_replace_all(url, "CB2010/CB", "CB2010/C"), url
    ),
    url = case_when(
      month == "Ene" & year == 2010 ~ str_replace(url, "Ene","enero"),
      month == "Feb" & year == 2010 ~ str_replace(url, "Feb","febrero"),
      month == "Mar" & year == 2010 ~ str_replace(url, "Mar","marzo"),
      month == "Abr" & year == 2010 ~ str_replace(url, "Abr","abril"),
      month == "May" & year == 2010 ~ str_replace(url, "May","mayo"),
      month == "Jun" & year == 2010 ~ str_replace(url, "Jun","junio"),
      month == "Jul" & year == 2010 ~ str_replace(url, "Jul","julio"),
      month == "Ago" & year == 2010 ~ str_replace(url, "Ago","agost"),
      month == "Sep" & year == 2010 ~ str_replace(url, "Sep","sept"),
      month == "Oct" & year == 2010 ~ str_replace(url, "Oct","oct"),
      month == "Nov" & year == 2010 ~ str_replace(url, "Nov","nov"),
      month == "Dic" & year == 2010 ~ str_replace(url, "Dic","dic"),
      TRUE ~ url
    ),
    ## 2022
    url = case_when(
      month == "Jun" & year == 2022 ~ str_replace(url, "Jun","Junio"),
      month == "Jul" & year == 2022 ~ str_replace(url, "Jul","Julio"),
      TRUE ~ url
    ),
    id = row_number(),
    url = ifelse(id >= 178, str_replace_all(url, ".xls", ".xlsx"), url)
  ) 

files <- files %>% 
  filter(id <= 186)



# Packages ----------------------------------------------------------------

pacman::p_load(tidyverse, janitor, lubridate, hrbrthemes)

# Get data ----------------------------------------------------------------

df <- read_rds("data/CB_FULL.rds")

# Ejemplo con el arroz ----------------------------------------------------

df %>% 
  filter(bien == "Arroz") %>% 
  mutate(
    ym = paste0(year, "-",as.numeric(month)),
    ym = ym(ym)
  ) %>% 
  ggplot(
    aes(
      x = ym,
      y = precio
    )
  ) +
  geom_line() +
  theme_ipsum_rc() +
  labs(
    x = "",
    y = "Precio en Córdobas",
    title = "Precio nominal de la libra de Arroz según la Canasta Básica de Nicaragua",
    subtitle = "Sep 2007 - Dic 2021",
    caption = "Fuente: INIDE | Plot: @rrmaximiliano"
  )

ggsave(
  "figures/arroz.png",
  dpi = 320,
  height = 8,
  width = 12,
  scale = 0.8,
  bg = "white"
)


# Queso -------------------------------------------------------------------


df %>% 
  filter(bien == "Queso seco") %>% 
  mutate(
    ym = paste0(year, "-",as.numeric(month)),
    ym = ym(ym)
  ) %>% 
  ggplot(
    aes(
      x = ym,
      y = precio
    )
  ) +
  geom_line() +
  theme_ipsum_rc() +
  labs(
    x = "",
    y = "Precio en Córdobas",
    title = "Precio nominal de la libra de Queso Seco según la Canasta Básica de Nicaragua",
    subtitle = "Sep 2007 - Dic 2021",
    caption = "Fuente: INIDE | Plot: @rrmaximiliano"
  )

ggsave(
  "figures/queso_seco.png",
  dpi = 320,
  height = 8,
  width = 12,
  scale = 0.8,
  bg = "white"
)

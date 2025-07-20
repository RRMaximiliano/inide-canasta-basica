
# Packages ----------------------------------------------------------------

pacman::p_load(tidyverse, janitor, lubridate, hrbrthemes, glue)

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
    subtitle = "Sep 2007 - Jun 2023",
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
    subtitle = "Sep 2007 - Jun 2023",
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

# All products ------------------------------------------------------------

df %>%
  mutate(
    bien = ifelse(str_detect(bien, "Brassier"), "Brassiers / Sostén", bien),
    bien = ifelse(str_detect(bien, "Desodorante"), "Desodorante", bien),
    bien = ifelse(str_detect(bien, "pescado|Pescado"), "Chuleta de Pescado", bien),
    bien = ifelse(str_detect(bien, "Leche"), "Leche", bien),
    bien = ifelse(str_detect(bien, "Detergente"), "Detergente", bien),
    bien = ifelse(str_detect(bien, "Jabón de lavar"), "Jabón de lavar", bien),
    bien = ifelse(str_detect(bien, "Pastas dental"), "Pasta dental", bien),
    bien = ifelse(str_detect(bien, "cuero natural"), "Zapato de cuero natural", bien),
    bien = ifelse(row == 39, glue("{bien} (Hombres y Niños)"), bien),
    bien = ifelse(row == 45, glue("{bien} (Mujeres y Niñas)"), bien),
    bien = ifelse(row == 42, glue("{bien} (> 10 años)"), bien),
    bien = ifelse(row == 52, glue("{bien} (< 10 años)"), bien)
  ) %>% 
  # group_by(bien) %>%  
  mutate(
    ym = paste0(year, "-",as.numeric(month)),
    ym = ym(ym)
  ) %>% 
  group_by(bien) %>% 
  mutate(
    pct = (total - lag(total)) / lag(total)
  ) %>% 
  arrange(bien, ym) %>%
  ggplot(
    aes(
      x = ym,
      y = precio,
      group = bien
    )
  ) +
  geom_line() +
  facet_wrap(~ bien, scales = "free_y") + 
  theme_ipsum_rc() +
  labs(
    x = "",
    y = "Precio en Córdobas",
    title = "Precio nominal de todos los 53 bienes de la la Canasta Básica de Nicaragua",
    subtitle = "Sep 2007 - Jun 2023",
    caption = "Fuente: INIDE | Plot: @rrmaximiliano"
  )


# Total -------------------------------------------------------------------

df %>% 
  group_by(year, month) %>% 
  summarize(
    sum = sum(total)
  ) %>% 
  mutate(
    ym = paste0(year, "-",as.numeric(month)),
    ym = ym(ym)
  ) %>% 
  ggplot(
    aes(
      x = ym,
      y = sum
    )
  ) +
  geom_line() +
  labs(
    x = "",
    y = "Precio en Córdobas",
    title = "Precio nominal total de la canasta básica",
    caption = "Fuente: INIDE | Plot: @rrmaximiliano"
  ) +
  scale_y_continuous(labels = scales::comma) +
  theme_ipsum_rc() +
  theme(
    axis.text.x = element_text(size = 16),
    axis.text.y = element_text(size = 16),
    axis.title = element_text(size = 18, face = "bold"),
    plot.title = element_text(size = 20, face = "bold"),
    plot.subtitle = element_text(size = 18),
    plot.caption = element_text(size = 14)
  )

ggsave(
  "figures/canasta_basica.png",
  dpi = 320,
  height = 8,
  width = 12,
  scale = 0.8,
  bg = "white"
)

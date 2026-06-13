# Automated plot generation for Nicaragua Canasta Básica
# This script generates figures used in README.md with dynamic dates

# Packages ----------------------------------------------------------------

library(dplyr)
library(readr)
library(ggplot2)
library(lubridate)
library(glue)
library(scales)
library(tidyr)

# Base year for real prices (single source of truth)
source("R/ipc.R")

# Get data ----------------------------------------------------------------

df <- read_rds("data/CB_FULL.rds")

month_levels <- c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
                  "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")

# Get dynamic date range for subtitles
min_year <- min(df$year)
max_year <- max(df$year)

min_month_data <- df %>%
  filter(year == min_year) %>%
  arrange(match(month, month_levels)) %>%
  slice(1)
min_month <- min_month_data$month

max_month_data <- df %>%
  filter(year == max_year) %>%
  arrange(desc(match(month, month_levels))) %>%
  slice(1)
max_month <- max_month_data$month

# Create dynamic subtitle
date_range <- glue("{min_month} {min_year} - {max_month} {max_year}")

cat("Generating plots with date range:", date_range, "\n")

# Arroz plot -------------------------------------------------------------

cat("Generating Arroz plot...\n")

arroz_plot <- df %>%
  filter(good == "Arroz") %>%
  ggplot(
    aes(
      x = ym,
      y = precio
    )
  ) +
  geom_line(color = "#2E86AB", linewidth = 1.2) +
  theme_minimal(base_size = 12) +
  labs(
    x = "",
    y = "Precio en Córdobas",
    title = "Precio nominal de la libra de Arroz según la Canasta Básica de Nicaragua",
    subtitle = date_range,
    caption = "Fuente: INIDE | Plot: @rrmaximiliano"
  ) +
  theme(
    plot.title = element_text(size = 18, face = "bold"),
    plot.subtitle = element_text(size = 14),
    axis.title.y = element_text(size = 12),
    plot.caption = element_text(size = 10)
  )

ggsave(
  "figures/arroz.png",
  plot = arroz_plot,
  dpi = 320,
  height = 8,
  width = 12,
  scale = 0.8,
  bg = "white"
)

cat("Arroz plot saved\n")


# Queso Seco plot --------------------------------------------------------

cat("Generating Queso Seco plot...\n")

queso_plot <- df %>%
  filter(good == "Queso seco") %>%
  ggplot(
    aes(
      x = ym,
      y = precio
    )
  ) +
  geom_line(color = "#A23B72", linewidth = 1.2) +
  theme_minimal(base_size = 12) +
  labs(
    x = "",
    y = "Precio en Córdobas",
    title = "Precio nominal de la libra de Queso Seco según la Canasta Básica de Nicaragua",
    subtitle = date_range,
    caption = "Fuente: INIDE | Plot: @rrmaximiliano"
  ) +
  theme(
    plot.title = element_text(size = 18, face = "bold"),
    plot.subtitle = element_text(size = 14),
    axis.title.y = element_text(size = 12),
    plot.caption = element_text(size = 10)
  )

ggsave(
  "figures/queso_seco.png",
  plot = queso_plot,
  dpi = 320,
  height = 8,
  width = 12,
  scale = 0.8,
  bg = "white"
)

cat("Queso Seco plot saved\n")

# Total Canasta Básica plot ----------------------------------------------

cat("Generating Total Canasta Básica plot...\n")

total_plot <- df %>%
  group_by(ym) %>%
  summarize(
    sum = sum(total, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  ggplot(
    aes(
      x = ym,
      y = sum
    )
  ) +
  geom_line(color = "#F18F01", linewidth = 1.2) +
  labs(
    x = "",
    y = "Precio en Córdobas",
    title = "Precio nominal total de la canasta básica de Nicaragua",
    subtitle = date_range,
    caption = "Fuente: INIDE | Plot: @rrmaximiliano"
  ) +
  scale_y_continuous(labels = comma_format()) +
  theme_minimal(base_size = 12) +
  theme(
    axis.text.x = element_text(size = 12),
    axis.text.y = element_text(size = 12),
    axis.title = element_text(size = 14, face = "bold"),
    plot.title = element_text(size = 18, face = "bold"),
    plot.subtitle = element_text(size = 14),
    plot.caption = element_text(size = 10)
  )

ggsave(
  "figures/canasta_basica.png",
  plot = total_plot,
  dpi = 320,
  height = 8,
  width = 12,
  scale = 0.8,
  bg = "white"
)

cat("Total Canasta Básica plot saved\n")

# Nominal vs Real total plot ---------------------------------------------

cat("Generating Nominal vs Real plot...\n")

real_label <- glue("Real (córdobas de {IPC_BASE_YEAR})")

totales_long <- df %>%
  group_by(ym) %>%
  summarize(
    Nominal = sum(total, na.rm = TRUE),
    Real    = sum(total_real, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_longer(c(Nominal, Real), names_to = "tipo", values_to = "valor") %>%
  mutate(tipo = if_else(tipo == "Real", real_label, "Nominal"))

nominal_real_plot <- totales_long %>%
  ggplot(aes(x = ym, y = valor, color = tipo)) +
  geom_line(linewidth = 1.2) +
  scale_color_manual(values = c("#F18F01", "#2E86AB")) +
  scale_y_continuous(labels = comma_format()) +
  labs(
    x = "",
    y = "Córdobas",
    color = "",
    title = "Canasta básica de Nicaragua: precio nominal vs. real",
    subtitle = glue("{date_range} | precios reales en córdobas constantes de {IPC_BASE_YEAR}"),
    caption = "Fuente: INIDE | IPC: FMI/IFS vía DBnomics | Plot: @rrmaximiliano"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    axis.title = element_text(size = 14, face = "bold"),
    plot.title = element_text(size = 18, face = "bold"),
    plot.subtitle = element_text(size = 13),
    plot.caption = element_text(size = 10)
  )

ggsave(
  "figures/canasta_nominal_real.png",
  plot = nominal_real_plot,
  dpi = 320,
  height = 8,
  width = 12,
  scale = 0.8,
  bg = "white"
)

cat("Nominal vs Real plot saved\n")

# Cost by category plot --------------------------------------------------

cat("Generating category plot...\n")

categoria_plot <- df %>%
  group_by(ym, categoria) %>%
  summarize(
    sum = sum(total, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  ggplot(aes(x = ym, y = sum, color = categoria)) +
  geom_line(linewidth = 1.1) +
  scale_color_manual(values = c(
    "Alimentos"      = "#2E86AB",
    "Usos del Hogar" = "#F18F01",
    "Vestuario"      = "#A23B72"
  )) +
  scale_y_continuous(labels = comma_format()) +
  labs(
    x = "",
    y = "Precio en Córdobas",
    color = "Categoría",
    title = "Costo nominal de la canasta básica por categoría",
    subtitle = date_range,
    caption = "Fuente: INIDE | Plot: @rrmaximiliano"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    axis.title = element_text(size = 14, face = "bold"),
    plot.title = element_text(size = 18, face = "bold"),
    plot.subtitle = element_text(size = 14),
    plot.caption = element_text(size = 10)
  )

ggsave(
  "figures/canasta_categoria.png",
  plot = categoria_plot,
  dpi = 320,
  height = 8,
  width = 12,
  scale = 0.8,
  bg = "white"
)

cat("Category plot saved\n")

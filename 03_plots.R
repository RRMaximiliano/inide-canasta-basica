
# Automated plot generation for Nicaragua Canasta Básica
# This script generates figures used in README.md with dynamic dates

# Packages ----------------------------------------------------------------

library(dplyr)
library(readr)
library(ggplot2)
library(lubridate)
library(hrbrthemes)
library(glue)
library(scales)

# Get data ----------------------------------------------------------------

df <- read_rds("data/CB_FULL.rds")

# Get dynamic date range for subtitles
min_year <- min(df$year)
max_year <- max(df$year)
min_month <- df$month[df$year == min_year][1]
max_month_data <- df %>% 
  filter(year == max_year) %>% 
  slice_tail(n = 1)
max_month <- max_month_data$month

# Create dynamic subtitle
date_range <- glue("{min_month} {min_year} - {max_month} {max_year}")

cat("Generating plots with date range:", date_range, "\n")

# Arroz plot -------------------------------------------------------------

cat("Generating Arroz plot...\n")

arroz_plot <- df %>% 
  filter(good == "Arroz") %>% 
  mutate(
    ym = paste0(year, "-", as.numeric(month)),
    ym = ym(ym)
  ) %>% 
  ggplot(
    aes(
      x = ym,
      y = precio
    )
  ) +
  geom_line(color = "#2E86AB", linewidth = 1.2) +
  theme_ipsum_rc() +
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

cat("✅ Arroz plot saved\n")


# Queso Seco plot --------------------------------------------------------

cat("Generating Queso Seco plot...\n")

queso_plot <- df %>% 
  filter(good == "Queso seco") %>% 
  mutate(
    ym = paste0(year, "-", as.numeric(month)),
    ym = ym(ym)
  ) %>% 
  ggplot(
    aes(
      x = ym,
      y = precio
    )
  ) +
  geom_line(color = "#A23B72", linewidth = 1.2) +
  theme_ipsum_rc() +
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

cat("✅ Queso Seco plot saved\n")

# Total Canasta Básica plot ----------------------------------------------

cat("Generating Total Canasta Básica plot...\n")

total_plot <- df %>% 
  group_by(year, month) %>% 
  summarize(
    sum = sum(total, na.rm = TRUE),
    .groups = "drop"
  ) %>% 
  mutate(
    ym = paste0(year, "-", as.numeric(month)),
    ym = ym(ym)
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
  theme_ipsum_rc() +
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

cat("✅ Total Canasta Básica plot saved\n")

# Summary -----------------------------------------------------------------

cat("\n🎨 Plot generation completed successfully!\n")
cat("📊 Generated plots with data range:", date_range, "\n")
cat("📁 All plots saved to figures/ directory\n")
cat("🔄 Plots are ready for README.md\n")

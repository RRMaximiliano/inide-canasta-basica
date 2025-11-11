library(readr)
library(dplyr)

data <- read_rds('data/CB_FULL.rds')

cat("Total rows:", nrow(data), "\n")
cat("Date range:", min(data$year), "-", max(data$year), "\n\n")

cat("Checking 2025 months:\n")
data %>% 
  filter(year == 2025) %>% 
  group_by(month) %>% 
  summarize(
    n = n(), 
    goods_not_na = sum(!is.na(good)),
    sample_goods = paste(head(good, 3), collapse = ", ")
  ) %>% 
  print()

cat("\nChecking October 2025 specifically:\n")
oct_data <- data %>% filter(year == 2025, month == "Oct")
cat("Rows:", nrow(oct_data), "\n")
cat("Sample goods:", paste(head(oct_data$good, 5), collapse = ", "), "\n")

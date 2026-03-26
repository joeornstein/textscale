## code to prepare `ad_tone` and `ad_tone_validation` datasets

# Requires the document-scaling project results file.
# Source: Carlson, T. N., & Montgomery, J. M. (2017). A pairwise comparison
# framework for fast, flexible, and reliable human coding of political texts.
# American Political Science Review, 111(4), 835–843.
# https://doi.org/10.1017/S0003055417000302

library(dplyr)

results <- readRDS(
  "~/projects/document-scaling/data/processed/ad-tone/results.rds"
)

tone_labels <- c(
  "1" = "Promoting",
  "2" = "Mostly promoting",
  "3" = "Contrasting",
  "4" = "Mostly attacking",
  "5" = "Attacking"
)

ad_tone <- results$docInfo |>
  select(text, candidate, state, tone, alphas, score, score_lower, score_upper, split) |>
  mutate(
    tone_label = factor(tone_labels[as.character(tone)], levels = tone_labels)
  ) |>
  as_tibble()

ad_tone_validation <- results$validation

usethis::use_data(ad_tone, ad_tone_validation, overwrite = TRUE)

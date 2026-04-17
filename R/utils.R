# Create the parent directory of a file path if it does not already exist.
.ensure_dir <- function(path) {
  dir <- dirname(path)
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
}

# Compute an MD5 hash of one or more strings (concatenated).
# Uses a temp file so no additional package dependencies are needed.
.prompt_hash <- function(...) {
  tmp <- tempfile()
  on.exit(unlink(tmp))
  writeLines(paste(..., sep = "\n"), tmp)
  unname(tools::md5sum(tmp))
}

# Agresti-Coull confidence interval for a binomial proportion.
# More reliable than the Wald interval for small n or p near 0/1.
.agresti_coull_ci <- function(x, n, level = 0.95) {
  if (n == 0) return(c(lower = NA_real_, upper = NA_real_))
  z          <- stats::qnorm(1 - (1 - level) / 2)
  n_tilde    <- n + z^2
  p_tilde    <- (x + z^2 / 2) / n_tilde
  half_width <- z * sqrt(p_tilde * (1 - p_tilde) / n_tilde)
  c(lower = max(0, p_tilde - half_width),
    upper = min(1, p_tilde + half_width))
}

# Check validation metrics and issue warnings or errors as appropriate.
# Prints the validation object before stopping so the user always sees
# the diagnostics. force = TRUE downgrades stops to warnings.
#
# Accuracy thresholds are applied to the upper bound of the 95%
# Agresti-Coull CI rather than the point estimate, so small test sets
# are not hard-stopped on noise (for large n, upper ≈ point estimate).
.check_validation_metrics <- function(validation, force = FALSE) {
  acc     <- validation$metrics$accuracy
  acc_hi  <- validation$metrics$accuracy_upper
  ici     <- validation$metrics$ici

  force_hint <- paste0(
    "To retrieve the full validation object (e.g. for plot()), set\n",
    "force = TRUE in textscale() or validate_model()."
  )

  .issue <- function(msg, is_stop) {
    if (is_stop && !force) {
      print(validation)
      stop(paste0(msg, "\n", force_hint), call. = FALSE)
    } else {
      warning(msg, call. = FALSE)
    }
  }

  # Accuracy checks based on CI upper bound (hard stop < 0.55; soft < 0.65)
  acc_msg <- function(label) sprintf(
    "Model accuracy is %.1f%% (95%% CI: %.1f%%-%.1f%%), %s.",
    100 * acc,
    100 * validation$metrics$accuracy_lower,
    100 * acc_hi,
    label
  )
  if (!is.na(acc_hi) && acc_hi < 0.55) {
    .issue(acc_msg("barely above chance. The rank ordering of document scores is unlikely to be meaningful"),
           is_stop = TRUE)
  } else if (!is.na(acc_hi) && acc_hi < 0.65) {
    warning(acc_msg("which is low. Document rankings may not reliably reflect the target dimension"),
            call. = FALSE)
  }

  # ICI checks (skipped entirely when calibration was not assessed)
  if (!is.na(ici)) {
    if (ici > 0.20) {
      .issue(sprintf(
        "Model ICI is %.3f, indicating severe miscalibration. Scores should not be trusted.",
        ici
      ), is_stop = TRUE)
    } else if (ici > 0.10) {
      warning(sprintf(
        "Model ICI is %.3f, indicating poor calibration. Scores should be interpreted with caution, though document rankings may still be valid.",
        ici
      ), call. = FALSE)
    }
  }
}

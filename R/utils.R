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

# Check validation metrics and issue warnings or errors as appropriate.
# Prints the validation object before stopping so the user always sees
# the diagnostics. force = TRUE downgrades stops to warnings.
.check_validation_metrics <- function(validation, force = FALSE) {
  acc <- validation$metrics$accuracy
  ici <- validation$metrics$ici

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

  # Accuracy checks (hard stop < 0.55; soft warning < 0.65)
  if (acc < 0.55) {
    .issue(sprintf(
      "Model accuracy is %.1f%%, barely above chance. The rank ordering of document scores is unlikely to be meaningful.",
      100 * acc
    ), is_stop = TRUE)
  } else if (acc < 0.65) {
    warning(sprintf(
      "Model accuracy is %.1f%%, which is low. Document rankings may not reliably reflect the target dimension.",
      100 * acc
    ), call. = FALSE)
  }

  # ICI checks (hard stop > 0.20; soft warning > 0.10)
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

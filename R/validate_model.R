utils::globalVariables(c("prob", "result", "mean_pred", "obs_prop", "n"))

#' Validate a textscale model on held-out comparisons
#'
#' Evaluates how well a fitted textscale model predicts the outcome of
#' held-out pairwise comparisons. For each pair, the document with the
#' higher latent score is predicted to win; this is compared against the
#' observed `winner` label.
#'
#' The **Integrated Calibration Index (ICI)** is the mean absolute
#' deviation of the calibration smooth from the diagonal, evaluated over
#' a fine grid. It expresses the average miscalibration in probability
#' units (e.g. 0.05 = predicted probabilities are off by ~5 percentage
#' points on average). Values below ~0.03 are typical of well-calibrated
#' models; values above ~0.07 suggest the model's predicted probabilities
#' should be interpreted cautiously, though the rank ordering of document
#' scores may still be valid.
#'
#' When `comparisons` contains a `split` column (produced by
#' [textscale::generate_comparisons()] with `prop` supplied), only the
#' rows where `split == "test"` are evaluated. `embeddings` should be
#' the full document embedding matrix in this case; `doc_id_a` and
#' `doc_id_b` index into it directly.
#'
#' @param model A `textscale_model` object produced by
#'   [textscale::fit_model()].
#' @param comparisons An annotated comparisons tibble produced by
#'   [textscale::annotate_comparisons()]. If a `split` column is
#'   present, only test-set rows are used.
#' @param embeddings A numeric matrix of document embeddings. Row `i`
#'   must correspond to document `i` in the original `documents` vector
#'   passed to [textscale::generate_comparisons()].
#' @param force Logical. If `FALSE` (the default), the function stops
#'   when accuracy is below 0.55 or ICI exceeds 0.20, and warns when
#'   accuracy is below 0.65 or ICI exceeds 0.10. Set `force = TRUE` to
#'   downgrade stops to warnings and continue anyway. When calling via
#'   [textscale()], pass `force = TRUE` there instead.
#'
#' @return A `textscale_validation` object. Call [print()] to display
#'   the accuracy and ICI metrics; call [plot()] to display a calibration
#'   plot and retrieve the underlying `ggplot` object.
#'
#' @export
validate_model <- function(model, comparisons, embeddings, force = FALSE) {
  if ("split" %in% names(comparisons)) {
    comparisons <- comparisons[comparisons$split == "test", ]
  }

  # Drop ties (cannot be evaluated in a binary prediction framework)
  is_tie <- comparisons$winner == "tie"
  n_ties_dropped <- sum(is_tie, na.rm = TRUE)
  if (n_ties_dropped > 0) {
    comparisons <- comparisons[!is_tie | is.na(is_tie), ]
  }

  scores     <- score_documents(model, embeddings)
  score_diff <- scores[comparisons$doc_id_a] - scores[comparisons$doc_id_b]
  prob       <- plogis(score_diff)
  predicted  <- ifelse(prob > 0.5, "A", "B")

  n_correct <- sum(predicted == comparisons$winner, na.rm = TRUE)

  # Integrated Calibration Index: mean absolute deviation of the
  # calibration smooth from the 45-degree line
  cal_df  <- data.frame(prob = prob, result = as.numeric(comparisons$winner == "A"))
  gam_fit <- mgcv::gam(result ~ s(prob, bs = "cs"), data = cal_df)
  grid    <- seq(0.01, 0.99, by = 0.005)
  fitted  <- as.numeric(predict(gam_fit, newdata = data.frame(prob = grid)))
  ici     <- mean(abs(fitted - grid))

  acc <- n_correct / nrow(comparisons)

  metrics <- tibble::tibble(
    n_pairs   = nrow(comparisons),
    n_correct = n_correct,
    accuracy  = acc,
    ici       = ici
  )

  out <- structure(
    list(metrics = metrics, cal_df = cal_df, ici = ici,
         n_ties_dropped = n_ties_dropped),
    class = "textscale_validation"
  )

  .check_validation_metrics(out, force = force)

  out
}

#' @export
print.textscale_validation <- function(x, ...) {
  cat("textscale model validation\n")
  if (x$n_ties_dropped > 0) {
    cat(sprintf(
      "(%s tie(s) excluded from evaluation)\n",
      format(x$n_ties_dropped, big.mark = ",")
    ))
  }
  cat("\n")
  print(x$metrics)
  invisible(x)
}

#' @rdname validate_model
#' @param x A `textscale_validation` object.
#' @param bins Number of equal-width bins for the reliability diagram
#'   points. Default is 10.
#' @param ... Ignored.
#'
#' @return `plot()` returns the `ggplot` calibration plot invisibly.
#'
#' @export
plot.textscale_validation <- function(x, bins = 10, ...) {
  cal_df         <- x$cal_df
  ici            <- x$ici
  n_ties_dropped <- x$n_ties_dropped %||% 0L

  # Bin observed proportions for reliability diagram points
  breaks <- seq(0, 1, length.out = bins + 1)
  cuts   <- cut(cal_df$prob, breaks = breaks, include.lowest = TRUE)
  bin_df <- data.frame(
    mean_pred = tapply(cal_df$prob,   cuts, mean,   na.rm = TRUE),
    obs_prop  = tapply(cal_df$result, cuts, mean,   na.rm = TRUE),
    n         = tapply(cal_df$result, cuts, length)
  )
  bin_df <- bin_df[!is.na(bin_df$obs_prop), ]

  p <- ggplot2::ggplot(cal_df, ggplot2::aes(x = prob, y = result)) +
    ggplot2::geom_abline(
      intercept = 0, slope = 1,
      linetype = "dashed", color = "grey50", linewidth = 0.5
    ) +

    ggplot2::geom_smooth(
      method    = "gam",
      formula   = y ~ s(x, bs = "cs"),
      color     = "#2166AC",
      fill      = "#2166AC",
      alpha     = 0.15,
      linewidth = 0.9
    ) +
    ggplot2::geom_point(
      data  = bin_df,
      ggplot2::aes(x = mean_pred, y = obs_prop, size = n),
      shape = 21, fill = "white", color = "#2166AC", stroke = 0.9
    ) +
    ggplot2::scale_x_continuous(
      labels = scales::percent_format(),
      limits = c(0, 1), expand = ggplot2::expansion(add = 0.01)
    ) +
    ggplot2::scale_y_continuous(
      labels = scales::percent_format(),
      limits = c(0, 1), expand = ggplot2::expansion(add = 0.01)
    ) +
    ggplot2::scale_size_continuous(range = c(2, 8), name = "Pairs") +
    ggplot2::labs(
      title   = "Calibration plot",
      x       = "Predicted P(A wins)",
      y       = "Observed P(A wins)",
      caption = if (n_ties_dropped > 0) {
        paste0("ICI = ", round(ici, 3),
               " (", format(n_ties_dropped, big.mark = ","), " tie(s) excluded)")
      } else {
        paste0("ICI = ", round(ici, 3))
      }
    ) +
    ggplot2::theme_minimal()

  print(p)
  invisible(p)
}

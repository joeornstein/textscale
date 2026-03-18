#' Validate a textscale model on held-out comparisons
#'
#' Evaluates how well a fitted textscale model predicts the outcome of
#' held-out pairwise comparisons. For each pair, the document with the
#' higher latent score is predicted to win; this is compared against the
#' observed `winner` label.
#'
#' A calibration plot of predicted P(A wins) against the observed
#' proportion of A wins is printed by default. Perfect calibration
#' corresponds to the 45° reference line.
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
#' @param plot Logical. If `TRUE` (the default), a calibration plot is
#'   printed.
#'
#' @return A tibble with columns `n_pairs`, `n_correct`, `accuracy`,
#'   and `ici` (Integrated Calibration Index).
#'
#' @export
validate_model <- function(model, comparisons, embeddings, plot = TRUE) {
  if ("split" %in% names(comparisons)) {
    comparisons <- comparisons[comparisons$split == "test", ]
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

  result <- tibble::tibble(
    n_pairs   = nrow(comparisons),
    n_correct = n_correct,
    accuracy  = n_correct / nrow(comparisons),
    ici       = ici
  )

  if (plot) {
    p <- ggplot2::ggplot(cal_df, ggplot2::aes(x = prob, y = result)) +
      ggplot2::geom_smooth() +
      ggplot2::geom_abline(intercept = 0, slope = 1, linetype = "dashed") +
      ggplot2::scale_x_continuous(labels = scales::percent_format()) +
      ggplot2::scale_y_continuous(labels = scales::percent_format()) +
      ggplot2::labs(
        x        = "Predicted P(A wins)",
        y        = "Observed proportion (A wins)",
        subtitle = paste0("ICI = ", round(ici, 3))
      )
    print(p)
  }

  result
}

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
#' @return A tibble with columns `n_pairs`, `n_correct`, and `accuracy`.
#'
#' @export
validate_model <- function(model, comparisons, embeddings, plot = TRUE) {
  if ("split" %in% names(comparisons)) {
    comparisons <- comparisons[comparisons$split == "test", ]
  }

  scores    <- score_documents(model, embeddings)
  score_diff <- scores[comparisons$doc_id_a] - scores[comparisons$doc_id_b]
  prob       <- plogis(score_diff)
  predicted  <- ifelse(prob > 0.5, "A", "B")

  n_correct <- sum(predicted == comparisons$winner, na.rm = TRUE)
  accuracy  <- tibble::tibble(
    n_pairs   = nrow(comparisons),
    n_correct = n_correct,
    accuracy  = n_correct / nrow(comparisons)
  )

  if (plot) {
    cal_df <- tibble::tibble(
      prob   = prob,
      result = as.numeric(comparisons$winner == "A")
    )
    p <- ggplot2::ggplot(cal_df, ggplot2::aes(x = prob, y = result)) +
      ggplot2::geom_smooth() +
      ggplot2::geom_abline(intercept = 0, slope = 1, linetype = "dashed") +
      ggplot2::scale_x_continuous(labels = scales::percent_format()) +
      ggplot2::scale_y_continuous(labels = scales::percent_format()) +
      ggplot2::labs(
        x = "Predicted P(A wins)",
        y = "Observed proportion (A wins)"
      )
    print(p)
  }

  accuracy
}

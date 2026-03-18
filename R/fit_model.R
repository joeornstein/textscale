#' Fit a textscale model
#'
#' Fits an L2-regularized logistic regression on the differences between
#' document embeddings to identify a latent scaling dimension. The
#' penalty parameter is selected by 10-fold cross-validation via
#' [glmnet::cv.glmnet()], then the model is refit at the optimal
#' lambda.
#'
#' @param comparisons An annotated tibble produced by
#'   [textscale::annotate_comparisons()], containing columns
#'   `doc_id_a`, `doc_id_b`, and `winner`.
#' @param embeddings A numeric matrix of document embeddings with one
#'   row per document. Row order must correspond to the integer indices
#'   in `comparisons` (i.e. row `i` is the embedding for the document
#'   at position `i` in the original `documents` vector passed to
#'   [textscale::generate_comparisons()]).
#' @param nlambda Number of lambda values to evaluate during
#'   cross-validation. Defaults to `200`.
#' @param lambda_min_ratio Ratio of the smallest to largest lambda
#'   evaluated. Defaults to `1e-9`. Increase if you see a warning that
#'   the optimal lambda is at the boundary of the search range.
#' @param ... Additional arguments passed to [glmnet::cv.glmnet()].
#'
#' @return A `textscale_model` object (a list) containing:
#'   \describe{
#'     \item{`beta`}{Coefficient vector defining the latent dimension
#'       (intercept excluded).}
#'     \item{`lambda`}{The selected regularization parameter.}
#'     \item{`cv_fit`}{The full [glmnet::cv.glmnet()] object.}
#'     \item{`glmnet_fit`}{The [glmnet::glmnet()] model refit at
#'       `lambda`.}
#'   }
#'
#' @export
fit_model <- function(
    comparisons,
    embeddings,
    nlambda = 200,
    lambda_min_ratio = 1e-9,
    ...) {
  if ("split" %in% names(comparisons)) {
    comparisons <- comparisons[comparisons$split == "train", ]
  }

  emb_diff <- embeddings[comparisons$doc_id_a, ] -
    embeddings[comparisons$doc_id_b, ]
  y <- as.numeric(comparisons$winner == "A")

  cv_fit <- glmnet::cv.glmnet(
    x = emb_diff,
    y = y,
    alpha = 0,
    family = "binomial",
    nlambda = nlambda,
    lambda.min.ratio = lambda_min_ratio,
    ...
  )

  if (min(cv_fit$lambda) == cv_fit$lambda.min) {
    warning(
      "Optimal lambda is at the lower boundary of the search range. ",
      "Consider decreasing `lambda_min_ratio`."
    )
  }

  final_fit <- glmnet::glmnet(
    x = emb_diff,
    y = y,
    alpha = 0,
    lambda = cv_fit$lambda.min,
    family = "binomial"
  )

  structure(
    list(
      beta      = as.numeric(coef(final_fit))[-1],
      lambda    = cv_fit$lambda.min,
      cv_fit    = cv_fit,
      glmnet_fit = final_fit
    ),
    class = "textscale_model"
  )
}

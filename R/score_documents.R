#' Score documents on the latent dimension
#'
#' Projects document embeddings onto the latent dimension identified by
#' a fitted textscale model. Scores are the linear predictor
#' `embeddings %*% beta` (i.e., log-odds, without the intercept), and
#' are therefore comparable across documents but arbitrary up to a
#' linear transformation.
#'
#' When `ci = TRUE`, a tibble is returned with columns `score`,
#' `lower`, and `upper` instead of a plain numeric vector.
#'
#' @section Confidence interval methods:
#'
#' **`"laplace"`** (default): Derives per-document score variances from
#' the Laplace approximation to the posterior covariance of `beta`:
#' `Var(score_i) = x_i' * (X'WX + lambda*I)^{-1} * x_i`, where `X`
#' is the matrix of training embedding differences and `W` is the
#' diagonal matrix of fitted working weights. This is fast (a single
#' matrix multiply) and treats `lambda` as fixed at the CV-selected
#' value. Not available for `method = "svm"` models.
#'
#' **`"bootstrap"`**: Resamples training pairs with replacement and
#' refits the model `n_boot` times at the original fixed `lambda`,
#' then takes empirical quantiles of the resulting score distributions.
#' Slower but propagates more of the sampling variability, and works
#' for all model types including `"svm"`. Requires `comparisons` to
#' be supplied.
#'
#' @param model A `textscale_model` object produced by
#'   [textscale::fit_model()].
#' @param embeddings A numeric matrix of document embeddings to score,
#'   with one row per document.
#' @param ci Logical. If `TRUE`, return a tibble with `score`,
#'   `lower`, and `upper` columns. Defaults to `FALSE`.
#' @param level Confidence level for the interval. Defaults to `0.95`.
#' @param ci_method One of `"laplace"` (default) or `"bootstrap"`.
#'   See **Confidence interval methods** for details.
#' @param n_boot Number of bootstrap resamples. Defaults to `500`.
#'   Ignored when `ci_method = "laplace"`.
#' @param comparisons Annotated comparisons tibble produced by
#'   [textscale::annotate_comparisons()]. Required when
#'   `ci_method = "bootstrap"`. If a `split` column is present, only
#'   training rows are resampled.
#'
#' @return When `ci = FALSE` (the default), a numeric vector of latent
#'   dimension scores, one per document. When `ci = TRUE`, a tibble
#'   with columns `score`, `lower`, and `upper`.
#'
#' @export
score_documents <- function(
    model,
    embeddings,
    ci = FALSE,
    level = 0.95,
    ci_method = c("laplace", "bootstrap"),
    n_boot = 500,
    comparisons = NULL) {
  scores <- as.numeric(embeddings %*% model$beta)

  if (!ci) {
    return(scores)
  }

  ci_method <- match.arg(ci_method)
  z <- qnorm(1 - (1 - level) / 2)

  if (ci_method == "laplace") {
    if (is.null(model$sigma_post)) {
      stop(
        "Laplace CIs are not available for method = '", model$method, "'. ",
        "Use ci_method = 'bootstrap' instead."
      )
    }
    # Var(x_i %*% beta) = x_i' sigma_post x_i, computed for all rows at once
    vars <- rowSums((embeddings %*% model$sigma_post) * embeddings)
    ses  <- sqrt(vars)
    return(tibble::tibble(
      score = scores,
      lower = scores - z * ses,
      upper = scores + z * ses
    ))
  }

  # Bootstrap ------------------------------------------------------------------
  if (is.null(comparisons)) {
    stop("`comparisons` must be supplied when ci_method = 'bootstrap'.")
  }

  if ("split" %in% names(comparisons)) {
    comparisons <- comparisons[comparisons$split == "train", ]
  }

  # Drop ties before resampling
  is_tie <- comparisons$winner == "tie"
  if (any(is_tie, na.rm = TRUE)) {
    comparisons <- comparisons[!is_tie | is.na(is_tie), ]
  }

  alpha_val <- switch(model$method, ridge = 0, lasso = 1, enet = 0.5, NULL)
  n_train   <- nrow(comparisons)
  boot_mat  <- matrix(NA_real_, nrow = nrow(embeddings), ncol = n_boot)

  lambda_msg <- if (!is.null(model$lambda)) {
    paste0(" (lambda fixed at ", round(model$lambda, 6), ")")
  } else {
    ""
  }
  message("Bootstrap CIs: ", n_boot, " resamples", lambda_msg, "...")

  for (b in seq_len(n_boot)) {
    idx    <- sample(n_train, replace = TRUE)
    comp_b <- comparisons[idx, ]
    diff_b <- embeddings[comp_b$doc_id_a, ] - embeddings[comp_b$doc_id_b, ]
    y_b    <- as.numeric(comp_b$winner == "A")

    if (!is.null(alpha_val)) {
      fit_b  <- glmnet::glmnet(diff_b, y_b, alpha = alpha_val,
                               lambda = model$lambda, family = "binomial")
      beta_b <- as.numeric(coef(fit_b))[-1]
    } else {
      fit_b  <- e1071::svm(diff_b, factor(y_b), kernel = "linear",
                           scale = FALSE)
      beta_b <- as.numeric(t(fit_b$coefs) %*% fit_b$SV)
    }

    # Align sign with original beta to handle arbitrary sign flips
    if (sum(beta_b * model$beta) < 0) beta_b <- -beta_b

    boot_mat[, b] <- as.numeric(embeddings %*% beta_b)
  }

  tibble::tibble(
    score = scores,
    lower = apply(boot_mat, 1, quantile, probs = (1 - level) / 2),
    upper = apply(boot_mat, 1, quantile, probs = 1 - (1 - level) / 2)
  )
}

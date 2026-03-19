#' Fit a textscale model
#'
#' Fits a model on the differences between document embeddings to
#' identify a latent scaling dimension. The default method is
#' L2-regularized logistic regression (`"ridge"`), with alternatives
#' including `"lasso"`, `"enet"` (elastic net), and `"svm"` (linear
#' support vector machine).
#'
#' @param comparisons An annotated tibble produced by
#'   [textscale::annotate_comparisons()], containing columns
#'   `doc_id_a`, `doc_id_b`, and `winner`.
#' @param embeddings A numeric matrix of document embeddings with one
#'   row per document. Row order must correspond to the integer indices
#'   in `comparisons` (i.e. row `i` is the embedding for the document
#'   at position `i` in the original `documents` vector passed to
#'   [textscale::generate_comparisons()]).
#' @param method One of `"ridge"` (default), `"lasso"`, `"enet"`, or
#'   `"svm"`. Controls the fitting method used to identify the latent
#'   dimension. `"ridge"`, `"lasso"`, and `"enet"` use
#'   [glmnet::cv.glmnet()] with alpha 0, 1, and `alpha` respectively.
#'   `"svm"` fits a linear support vector machine via
#'   [e1071::svm()].
#' @param alpha The elastic net mixing parameter, used only when
#'   `method = "enet"`. Must be between 0 and 1 (0 = ridge, 1 =
#'   lasso). Defaults to `0.5`.
#' @param nlambda Number of lambda values to evaluate during
#'   cross-validation. Defaults to `200`. Ignored when
#'   `method = "svm"`.
#' @param lambda_min_ratio Ratio of the smallest to largest lambda
#'   evaluated. Defaults to `1e-9`. Increase if you see a warning that
#'   the optimal lambda is at the boundary of the search range. Ignored
#'   when `method = "svm"`.
#' @param ... Additional arguments passed to [glmnet::cv.glmnet()]
#'   (for glmnet methods) or [e1071::svm()] (for `method = "svm"`).
#'
#' @return A `textscale_model` object (a list) containing:
#'   \describe{
#'     \item{`beta`}{Coefficient vector defining the latent dimension
#'       (intercept excluded).}
#'     \item{`method`}{The fitting method used.}
#'     \item{`lambda`}{The selected regularization parameter. Present
#'       for glmnet methods only.}
#'     \item{`cv_fit`}{The full [glmnet::cv.glmnet()] object. Present
#'       for glmnet methods only.}
#'     \item{`glmnet_fit`}{The [glmnet::glmnet()] model refit at
#'       `lambda`. Present for glmnet methods only.}
#'     \item{`svm_fit`}{The [e1071::svm()] model object. Present when
#'       `method = "svm"` only.}
#'   }
#'
#' @export
fit_model <- function(
    comparisons,
    embeddings,
    method = c("ridge", "lasso", "enet", "svm"),
    alpha = 0.5,
    nlambda = 200,
    lambda_min_ratio = 1e-9,
    ...) {
  method <- match.arg(method)

  if ("split" %in% names(comparisons)) {
    comparisons <- comparisons[comparisons$split == "train", ]
  }

  emb_diff <- embeddings[comparisons$doc_id_a, ] -
    embeddings[comparisons$doc_id_b, ]
  y <- as.numeric(comparisons$winner == "A")

  if (method %in% c("ridge", "lasso", "enet")) {
    alpha_val <- switch(method, ridge = 0, lasso = 1, enet = alpha)

    cv_fit <- glmnet::cv.glmnet(
      x = emb_diff,
      y = y,
      alpha = alpha_val,
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
      alpha = alpha_val,
      lambda = cv_fit$lambda.min,
      family = "binomial"
    )

    # Laplace posterior covariance: (X'WX + lambda*I)^{-1}
    # Used by score_documents() to compute per-document score CIs.
    probs      <- as.numeric(predict(final_fit, newx = emb_diff, type = "response"))
    w          <- probs * (1 - probs)
    XtWX       <- crossprod(sqrt(w) * emb_diff)
    sigma_post <- solve(XtWX + cv_fit$lambda.min * diag(ncol(emb_diff)))

    structure(
      list(
        beta       = as.numeric(coef(final_fit))[-1],
        method     = method,
        lambda     = cv_fit$lambda.min,
        cv_fit     = cv_fit,
        glmnet_fit = final_fit,
        sigma_post = sigma_post
      ),
      class = "textscale_model"
    )
  } else {
    svm_fit <- e1071::svm(
      x = emb_diff,
      y = factor(y),
      kernel = "linear",
      scale = FALSE,
      ...
    )

    structure(
      list(
        beta    = as.numeric(t(svm_fit$coefs) %*% svm_fit$SV),
        method  = "svm",
        svm_fit = svm_fit
      ),
      class = "textscale_model"
    )
  }
}
